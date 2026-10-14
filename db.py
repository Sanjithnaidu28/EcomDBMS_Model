"""Database access layer: one connection per request, parameterised SQL only,
and translation of MySQL errors (including trigger SIGNALs) into plain messages."""
import re
import mysql.connector
from flask import g
from config import DB_CONFIG, DEMO_MODE

if DEMO_MODE:
    import demo_db  # noqa: F401  (replaces mysql.connector.connect with the SQLite demo database)


def get_db():
    if "db" not in g:
        g.db = mysql.connector.connect(**DB_CONFIG)
        # reads auto-commit; writes use explicit transactions (run_transaction)
        g.db.autocommit = True
    return g.db


def close_db(_exc=None):
    db = g.pop("db", None)
    if db is not None and db.is_connected():
        db.close()


def query(sql, params=(), one=False):
    """Run a SELECT and return a list of dicts (or one dict / None)."""
    cur = get_db().cursor(dictionary=True)
    try:
        cur.execute(sql, params)
        rows = cur.fetchall()
    finally:
        cur.close()
    return (rows[0] if rows else None) if one else rows


def scalar(sql, params=()):
    row = query(sql, params, one=True)
    return next(iter(row.values())) if row else None


def execute(sql, params=()):
    """Run one INSERT / UPDATE / DELETE and commit. Returns the new id for inserts."""
    return run_transaction([(sql, params)])


def run_transaction(statements):
    """Run several statements as ONE transaction: all succeed or all are rolled back."""
    conn = get_db()
    cur = conn.cursor()
    try:
        conn.start_transaction()
        last_id = None
        for sql, params in statements:
            cur.execute(sql, params)
            last_id = cur.lastrowid or last_id
        conn.commit()
        return last_id
    except Exception:
        conn.rollback()
        raise
    finally:
        cur.close()


def call_procedure(name, args):
    """Call a stored procedure and return its (possibly modified) arguments."""
    conn = get_db()
    cur = conn.cursor()
    try:
        result = cur.callproc(name, args)
        conn.commit()
        return result
    except Exception:
        conn.rollback()
        raise
    finally:
        cur.close()


# Readable text for CHECK constraint names
CHECK_MESSAGES = {
    "chk_customer_email": "Enter a valid email address.",
    "chk_customer_phone": "Phone must be a 10-digit Indian mobile number starting with 6-9.",
    "chk_address_pincode": "Pincode must be 6 digits and cannot start with 0.",
    "chk_product_price": "Price must be greater than zero.",
    "chk_product_window": "Return window must be between 0 and 30 days.",
    "chk_inventory_qty": "Stock cannot go below zero.",
    "chk_inventory_reorder": "Reorder level cannot be negative.",
    "chk_cartitem_qty": "Quantity must be at least 1.",
    "chk_orderitem_qty": "Quantity must be at least 1.",
    "chk_refund_amount": "Refund amount must be greater than zero.",
    "chk_return_qty": "Return quantity must be at least 1.",
    "chk_review_rating": "Rating must be between 1 and 5.",
    "chk_shipment_delivered": "Delivery date cannot be before the shipped date.",
    "chk_shipment_done": "A delivered shipment needs a delivery date (and only delivered shipments have one).",
    "chk_shipment_expected": "Expected delivery cannot be before the shipped date.",
}


def friendly_error(err):
    """Turn a mysql.connector error into a sentence a user can act on."""
    errno = getattr(err, "errno", None)
    msg = getattr(err, "msg", str(err))
    if errno == 1644:                      # SIGNAL from a trigger / procedure
        return msg
    if errno == 1062:                      # duplicate key
        m = re.search(r"Duplicate entry '(.+?)' for key '(.+?)'", msg)
        if m:
            return f"'{m.group(1)}' already exists ({m.group(2).split('.')[-1].replace('uq_', '').replace('_', ' ')} must be unique)."
        return "That value already exists."
    if errno in (3819, 4025):              # CHECK constraint (MySQL / MariaDB)
        for name, text in CHECK_MESSAGES.items():
            if name in msg:
                return text
        return "A value is outside the allowed range."
    if errno == 1452:
        return "The linked record does not exist."
    if errno == 1451:
        return "This record is used elsewhere and cannot be deleted."
    if errno in (2003, 2005, 1045, 1049):
        return f"Cannot connect to the database: {msg}. Check that MySQL is running in XAMPP and the settings in config.py."
    return f"Database error {errno}: {msg}"
