"""Demo mode: run ShopDesk on a bundled SQLite copy of the database instead of MySQL.

Used for the hosted demo (DEMO_MODE=1), so the site works with no database server.
demo/shopdesk_demo.db has the same 15 tables, CHECK/UNIQUE/foreign-key constraints,
8 report views and sample data as the MySQL scripts, plus the business-rule triggers
ported to SQLite (same error messages). sp_place_order is implemented below as one
SQLite transaction, because SQLite has no stored procedures.

This module replaces mysql.connector.connect with a small adapter, so app.py and db.py
run unchanged. The real MySQL version is in database/ and is what the report describes.
"""
import os
import re
import shutil
import sqlite3
import datetime
import uuid
from decimal import Decimal

import mysql.connector

HERE = os.path.dirname(os.path.abspath(__file__))
SEED_DB = os.path.join(HERE, "demo", "shopdesk_demo.db")
DB_PATH = os.getenv("DEMO_DB_PATH", "/tmp/shopdesk_demo.db")

# Each fresh start of the server begins from the original sample data.
if not os.path.exists(DB_PATH):
    shutil.copyfile(SEED_DB, DB_PATH)

# UNIQUE constraint names (uq_...) per (table, columns), read from the schema itself
UNIQUE_NAMES = {}
with sqlite3.connect(SEED_DB) as _c:
    for _table, _ddl in _c.execute("SELECT name, sql FROM sqlite_master WHERE type = 'table'"):
        for _name, _cols in re.findall(r"CONSTRAINT\s+(\w+)\s+UNIQUE\s*\(([^)]*)\)", _ddl or ""):
            UNIQUE_NAMES[(_table, tuple(c.strip() for c in _cols.split(",")))] = _name


# ---------------------------------------------------------------------------
# SQL translation: the few MySQL-only constructs app.py uses
# ---------------------------------------------------------------------------
def _split_args(s):
    out, depth, cur, quote = [], 0, "", None
    for ch in s:
        if quote:
            cur += ch
            if ch == quote:
                quote = None
            continue
        if ch in "'\"":
            quote = ch
        elif ch == "(":
            depth += 1
        elif ch == ")":
            depth -= 1
        elif ch == "," and depth == 0:
            out.append(cur.strip())
            cur = ""
            continue
        cur += ch
    out.append(cur.strip())
    return out


def _replace_func(sql, name, fn):
    while True:
        m = re.search(r"\b" + name + r"\(", sql, re.I)
        if not m:
            return sql
        i = j = m.end()
        depth = 1
        while depth:
            if sql[j] == "(":
                depth += 1
            elif sql[j] == ")":
                depth -= 1
            j += 1
        sql = sql[:m.start()] + fn(_split_args(sql[i:j - 1])) + sql[j:]


UPSERT_TARGETS = {"cart_item": "cart_id, product_id"}


def translate(sql, session_vars):
    sql = _replace_func(sql, "CONCAT", lambda a: "(" + " || ".join(a) + ")")
    sql = _replace_func(sql, "FIELD", lambda a: "(CASE " + a[0] + " " +
                        " ".join(f"WHEN {v} THEN {k + 1}" for k, v in enumerate(a[1:])) + " ELSE 99 END)")
    m = re.search(r"ON DUPLICATE KEY UPDATE\s+(\w+)\s*=\s*\1\s*\+\s*VALUES\(\1\)", sql, re.I)
    if m:
        table = re.search(r"INSERT INTO (\w+)", sql, re.I).group(1)
        col = m.group(1)
        sql = sql[:m.start()] + (f"ON CONFLICT({UPSERT_TARGETS[table]}) DO UPDATE SET "
                                 f"{col} = {table}.{col} + excluded.{col}") + sql[m.end():]
    sql = re.sub(r"\bINSERT IGNORE\b", "INSERT OR IGNORE", sql, flags=re.I)
    sql = re.sub(r"\bNOW\(\)", "datetime('now')", sql, flags=re.I)
    sql = re.sub(r"\bCURDATE\(\)", "date('now')", sql, flags=re.I)
    sql = re.sub(r"\bLAST_INSERT_ID\(\)", "last_insert_rowid()", sql, flags=re.I)
    sql = re.sub(r"\bTRUE\b", "1", sql)
    sql = re.sub(r"\bFALSE\b", "0", sql)
    for name, value in session_vars.items():
        sql = re.sub(r"@" + name + r"\b", str(int(value)), sql)
    sql = re.sub(r"%\((\w+)\)s", r":\1", sql)
    return sql.replace("%s", "?")


def _param(v):
    if isinstance(v, Decimal):
        return float(v)
    if isinstance(v, datetime.datetime):
        return v.strftime("%Y-%m-%d %H:%M:%S")
    if isinstance(v, datetime.date):
        return v.isoformat()
    if isinstance(v, bool):
        return int(v)
    return v


DATE_RE = re.compile(r"\d{4}-\d{2}-\d{2}")
DATETIME_RE = re.compile(r"\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}")


def _value(v):
    """Return values the way mysql.connector would: Decimal money, date/datetime objects."""
    if isinstance(v, float):
        return Decimal(str(round(v, 2))).quantize(Decimal("0.01"))
    if isinstance(v, str):
        if DATE_RE.fullmatch(v):
            return datetime.date.fromisoformat(v)
        if DATETIME_RE.fullmatch(v):
            return datetime.datetime.strptime(v, "%Y-%m-%d %H:%M:%S")
    return v


# ---------------------------------------------------------------------------
# Errors: turn SQLite errors into the MySQL error numbers db.friendly_error() knows
# ---------------------------------------------------------------------------
def _value_for_column(sql, params, col):
    """Find the parameter supplied for `col` in an INSERT ... (cols) VALUES (%s, ...)."""
    if isinstance(params, dict):
        return params.get(col)
    m = re.search(r"INSERT INTO \w+\s*\(([^)]*)\)\s*VALUES\s*\(([^)]*)\)", sql or "", re.I)
    if not m:
        return None
    cols = [c.strip() for c in m.group(1).split(",")]
    vals = [v.strip() for v in m.group(2).split(",")]
    if col not in cols or len(cols) != len(vals):
        return None
    i = cols.index(col)
    if vals[i] not in ("%s", "?"):
        return None
    return params[sum(1 for v in vals[:i] if v in ("%s", "?"))]


def _mysql_error(e, params, sql=None):
    text = str(e)
    if text.startswith("UNIQUE constraint failed"):
        cols = [c.strip().split(".")[-1] for c in text.split(":", 1)[1].split(",")]
        table = text.split(":", 1)[1].strip().split(".")[0]
        value = _value_for_column(sql, params, cols[0]) if len(cols) == 1 else None
        key = f"{table}.{UNIQUE_NAMES.get((table, tuple(cols)), 'uq_' + '_'.join(cols))}"
        if value is not None:
            return mysql.connector.Error(msg=f"Duplicate entry '{value}' for key '{key}'", errno=1062)
        return mysql.connector.Error(msg="Duplicate entry", errno=1062)
    if text.startswith("CHECK constraint failed"):
        return mysql.connector.Error(msg=text, errno=4025)
    if text.startswith("FOREIGN KEY constraint failed"):
        return mysql.connector.Error(msg=text, errno=1452)
    if text.startswith("NOT NULL constraint failed"):
        return mysql.connector.Error(msg=text, errno=1048)
    if isinstance(e, sqlite3.IntegrityError):          # RAISE(ABORT, ...) from a business-rule trigger
        return mysql.connector.Error(msg=text, errno=1644)
    return mysql.connector.Error(msg=text, errno=1064)


def _signal(message):
    return mysql.connector.Error(msg=message, errno=1644)


# ---------------------------------------------------------------------------
# Connection and cursor with the mysql.connector interface db.py uses
# ---------------------------------------------------------------------------
class DemoCursor:
    def __init__(self, conn, dictionary=False):
        self.conn = conn
        self.dictionary = dictionary
        self.cur = conn.sq.cursor()
        self.lastrowid = None

    def execute(self, sql, params=()):
        m = re.match(r"\s*SET\s+@(\w+)\s*=\s*LAST_INSERT_ID\(\)\s*$", sql, re.I)
        if m:
            self.conn.session_vars[m.group(1)] = self.conn.sq.execute("SELECT last_insert_rowid()").fetchone()[0]
            return
        if isinstance(params, dict):
            params = {k: _param(v) for k, v in params.items()}
        else:
            params = tuple(_param(v) for v in params)
        try:
            self.cur.execute(translate(sql, self.conn.session_vars), params)
        except (sqlite3.IntegrityError, sqlite3.OperationalError) as e:
            raise _mysql_error(e, params, sql) from None
        self.lastrowid = self.cur.lastrowid

    def fetchall(self):
        if self.cur.description is None:
            return []
        cols = [d[0] for d in self.cur.description]
        rows = [tuple(_value(v) for v in r) for r in self.cur.fetchall()]
        return [dict(zip(cols, r)) for r in rows] if self.dictionary else rows

    def callproc(self, name, args):
        if name != "sp_place_order":
            raise mysql.connector.Error(msg=f"PROCEDURE {name} does not exist", errno=1305)
        return self.conn.place_order(*args)

    def close(self):
        self.cur.close()


class DemoConnection:
    def __init__(self, **_ignored):
        self.sq = sqlite3.connect(DB_PATH, isolation_level=None, check_same_thread=False, timeout=10)
        self.sq.execute("PRAGMA foreign_keys = ON")
        self.session_vars = {}
        self.autocommit = True

    def cursor(self, dictionary=False, **_):
        return DemoCursor(self, dictionary)

    def start_transaction(self):
        if not self.sq.in_transaction:
            self.sq.execute("BEGIN IMMEDIATE")

    def commit(self):
        if self.sq.in_transaction:
            self.sq.execute("COMMIT")

    def rollback(self):
        if self.sq.in_transaction:
            self.sq.execute("ROLLBACK")

    def is_connected(self):
        return True

    def close(self):
        self.sq.close()

    # Port of sp_place_order: the whole checkout is ONE transaction (Rules 1 and 2).
    def place_order(self, customer_id, address_id, method, _out):
        q = self.sq.execute
        self.start_transaction()
        try:
            row = q("SELECT cart_id FROM cart WHERE customer_id = ?", (customer_id,)).fetchone()
            cart_id = row[0] if row else None
            items = q("SELECT COUNT(*) FROM cart_item WHERE cart_id = ?", (cart_id,)).fetchone()[0]
            if cart_id is None or items == 0:
                raise _signal("Cart is empty: an order needs at least one item.")
            if not q("SELECT 1 FROM address WHERE address_id = ? AND customer_id = ?",
                     (address_id, customer_id)).fetchone():
                raise _signal("Delivery address does not belong to this customer.")

            cur = q("INSERT INTO orders (order_number, customer_id, address_id, order_status) VALUES (?, ?, ?, 'Placed')",
                    ("TMP-" + uuid.uuid4().hex, customer_id, address_id))
            order_id = cur.lastrowid
            q("UPDATE orders SET order_number = ? WHERE order_id = ?", (f"ORD-{order_id:06d}", order_id))
            # current price copied into each item; the triggers check stock (Rule 1) and reduce it.
            # (MySQL inserts 0 and lets the BEFORE trigger set the price, to avoid error 1442;
            #  SQLite triggers cannot modify NEW, and SQLite has no 1442 restriction.)
            q("""INSERT INTO order_item (order_id, product_id, quantity, unit_price)
                 SELECT ?, ci.product_id, ci.quantity, p.unit_price
                   FROM cart_item ci JOIN product p ON p.product_id = ci.product_id
                  WHERE ci.cart_id = ?""", (order_id, cart_id))
            total = q("SELECT SUM(quantity * unit_price) FROM order_item WHERE order_id = ?", (order_id,)).fetchone()[0]
            q("""INSERT INTO payment (order_id, amount, payment_method, payment_status, transaction_ref)
                 VALUES (?, ?, ?, ?, ?)""",
              (order_id, total, method, "Pending" if method == "COD" else "Success",
               f"TXN-{order_id:06d}-{uuid.uuid4().hex[:6].upper()}"))
            q("UPDATE orders SET order_status = 'Confirmed' WHERE order_id = ?", (order_id,))
            q("DELETE FROM cart_item WHERE cart_id = ?", (cart_id,))
            self.commit()
            return (customer_id, address_id, method, order_id)
        except mysql.connector.Error:
            self.rollback()
            raise
        except (sqlite3.IntegrityError, sqlite3.OperationalError) as e:
            self.rollback()
            raise _mysql_error(e, ()) from None


mysql.connector.connect = DemoConnection
