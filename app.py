"""
E-Commerce Order, Return and Refund Management System
Flask front-end for the ecommerce_dbms MySQL/MariaDB database.
Author: Sanjith Naidu (25WU0101001T)

Run:  python3 app.py   then open http://127.0.0.1:5000
"""
import re
from datetime import date, timedelta
from decimal import Decimal, InvalidOperation

import mysql.connector
from flask import Flask, render_template, request, redirect, url_for, flash

from config import SECRET_KEY
from db import query, scalar, execute, run_transaction, call_procedure, close_db, friendly_error

app = Flask(__name__, template_folder="app/templates", static_folder="app/static")
app.secret_key = SECRET_KEY
app.teardown_appcontext(close_db)

ORDER_STATUSES = ["Placed", "Confirmed", "Shipped", "Delivered", "Cancelled"]
SHIPMENT_FLOW = ["Shipped", "In Transit", "Out for Delivery", "Delivered"]
RETURN_STATUSES = ["Requested", "Approved", "Rejected", "Received"]
PAYMENT_METHODS = ["UPI", "Card", "NetBanking", "COD"]
COURIERS = ["Delhivery", "Blue Dart", "Ekart", "India Post"]


# ----------------------------------------------------------------------
# Input validation helpers: raise ValueError with a message for the user
# ----------------------------------------------------------------------
def req_text(name, label, max_len=200):
    value = (request.form.get(name) or "").strip()
    if not value:
        raise ValueError(f"{label} is required.")
    if len(value) > max_len:
        raise ValueError(f"{label} must be at most {max_len} characters.")
    return value


def req_int(name, label, minimum=None, maximum=None):
    raw = (request.form.get(name) or "").strip()
    if not re.fullmatch(r"-?\d+", raw):
        raise ValueError(f"{label} must be a whole number.")
    value = int(raw)
    if minimum is not None and value < minimum:
        raise ValueError(f"{label} must be at least {minimum}.")
    if maximum is not None and value > maximum:
        raise ValueError(f"{label} must be at most {maximum}.")
    return value


def req_money(name, label):
    raw = (request.form.get(name) or "").strip()
    try:
        value = Decimal(raw).quantize(Decimal("0.01"))
    except (InvalidOperation, ValueError):
        raise ValueError(f"{label} must be an amount like 1499 or 1499.50.")
    if value <= 0:
        raise ValueError(f"{label} must be greater than zero.")
    return value


def req_date(name, label):
    raw = (request.form.get(name) or "").strip()
    try:
        return date.fromisoformat(raw)
    except ValueError:
        raise ValueError(f"{label} must be a valid date.")


def run_action(action, success, redirect_to):
    """Run a database action, show success or a readable error, then redirect."""
    try:
        action()
        flash(success, "success")
    except ValueError as e:                       # failed input validation
        flash(str(e), "error")
    except mysql.connector.Error as e:            # constraint / trigger / connection error
        flash(friendly_error(e), "error")
    return redirect(redirect_to)


@app.errorhandler(mysql.connector.Error)
def db_error(e):
    return render_template("error.html", message=friendly_error(e)), 500


@app.template_filter("inr")
def inr(value):
    if value is None:
        return "-"
    return "₹{:,.2f}".format(Decimal(value))


@app.context_processor
def globals_for_templates():
    return {"today": date.today()}


# ----------------------------------------------------------------------
# DASHBOARD
# ----------------------------------------------------------------------
@app.route("/")
def dashboard():
    order_counts = {r["order_status"]: r["orders"] for r in query(
        "SELECT order_status, COUNT(*) AS orders FROM orders GROUP BY order_status")}
    return_counts = {r["return_status"]: r["n"] for r in query(
        "SELECT return_status, COUNT(*) AS n FROM return_request GROUP BY return_status")}
    stats = {
        "orders": sum(order_counts.values()),
        "net_revenue": scalar("SELECT COALESCE(SUM(net_revenue), 0) FROM v_monthly_revenue"),
        "refunds_pending": scalar("SELECT COUNT(*) FROM refund WHERE refund_status = 'Initiated'"),
        "refunded": scalar("SELECT COALESCE(SUM(refund_amount), 0) FROM refund WHERE refund_status = 'Processed'"),
    }
    months = query("SELECT * FROM v_monthly_revenue ORDER BY month")
    peak = max([m["gross_revenue"] for m in months] or [1]) or 1
    for m in months:
        m["pct"] = round(100 * m["gross_revenue"] / peak)
        m["label"] = date(int(m["month"][:4]), int(m["month"][5:7]), 1).strftime("%b %Y")
    recent = query("SELECT * FROM v_order_summary ORDER BY order_id DESC LIMIT 8")
    low = query("SELECT * FROM v_stock_status WHERE stock_status IN ('Low stock', 'Out of stock') ORDER BY quantity_available")
    returns = query("""SELECT return_id, order_number, customer_name, product_name, request_date
                         FROM v_return_report WHERE return_status = 'Requested' ORDER BY request_date""")
    return render_template("dashboard.html", stats=stats, order_counts=order_counts, return_counts=return_counts,
                           months=months, recent=recent, low=low, returns=returns)


# ----------------------------------------------------------------------
# CATALOGUE MANAGEMENT (CRUD + search)
# ----------------------------------------------------------------------
def catalogue_lists():
    sellers = query("SELECT seller_id, store_name FROM seller ORDER BY store_name")
    categories = query("""SELECT c.category_id,
                                 CONCAT(COALESCE(CONCAT(p.category_name, ' › '), ''), c.category_name) AS label
                            FROM category c LEFT JOIN category p ON p.category_id = c.parent_category_id
                           ORDER BY label""")
    return sellers, categories


@app.route("/products")
def products():
    q = request.args.get("q", "").strip()
    cat = request.args.get("category", "0")
    cat = int(cat) if cat.isdigit() else 0
    show = request.args.get("show", "active")
    like = f"%{q}%"
    rows = query("""
        SELECT p.product_id, p.product_code, p.product_name, p.unit_price, p.return_window_days, p.is_active,
               c.category_name, s.store_name, i.quantity_available, i.reorder_level
          FROM product p
          JOIN category c  ON c.category_id = p.category_id
          JOIN seller s    ON s.seller_id   = p.seller_id
          JOIN inventory i ON i.product_id  = p.product_id
         WHERE (%s = '' OR p.product_name LIKE %s OR p.product_code LIKE %s OR s.store_name LIKE %s)
           AND (%s = 0 OR p.category_id = %s OR c.parent_category_id = %s)
           AND (%s = 'all' OR p.is_active = TRUE)
         ORDER BY p.product_code""", (q, like, like, like, cat, cat, cat, show))
    _, categories = catalogue_lists()
    return render_template("products.html", rows=rows, q=q, cat=cat, show=show, categories=categories)


def read_product_form():
    code = req_text("product_code", "Product code", 20).upper()
    if not re.fullmatch(r"[A-Z]{2}-[A-Z]{3}-\d{3}", code):
        raise ValueError("Product code must look like TN-MOB-003 (2 letters, 3 letters, 3 digits).")
    return {
        "product_code": code,
        "seller_id": req_int("seller_id", "Seller", 1),
        "category_id": req_int("category_id", "Category", 1),
        "product_name": req_text("product_name", "Product name", 120),
        "description": (request.form.get("description") or "").strip()[:500] or None,
        "unit_price": req_money("unit_price", "Price"),
        "return_window_days": req_int("return_window_days", "Return window", 0, 30),
    }


@app.route("/products/new", methods=["GET", "POST"])
def product_new():
    sellers, categories = catalogue_lists()
    if request.method == "POST":
        try:
            p = read_product_form()
            stock = req_int("quantity_available", "Opening stock", 0)
            reorder = req_int("reorder_level", "Reorder level", 0)
            # product and its inventory row are created together, or not at all
            pid = run_transaction([
                ("""INSERT INTO product (product_code, seller_id, category_id, product_name, description,
                                         unit_price, return_window_days)
                    VALUES (%(product_code)s, %(seller_id)s, %(category_id)s, %(product_name)s,
                            %(description)s, %(unit_price)s, %(return_window_days)s)""", p),
                ("INSERT INTO inventory (product_id, quantity_available, reorder_level) VALUES (LAST_INSERT_ID(), %s, %s)",
                 (stock, reorder)),
            ])
            flash(f"Product {p['product_code']} added.", "success")
            return redirect(url_for("products", q=p["product_code"]))
        except ValueError as e:
            flash(str(e), "error")
        except mysql.connector.Error as e:
            flash(friendly_error(e), "error")
    return render_template("product_form.html", product=request.form, sellers=sellers,
                           categories=categories, mode="new")


@app.route("/products/<int:pid>/edit", methods=["GET", "POST"])
def product_edit(pid):
    sellers, categories = catalogue_lists()
    product = query("""SELECT p.*, i.quantity_available, i.reorder_level FROM product p
                         JOIN inventory i ON i.product_id = p.product_id WHERE p.product_id = %s""", (pid,), one=True)
    if not product:
        flash("Product not found.", "error")
        return redirect(url_for("products"))
    if request.method == "POST":
        try:
            p = read_product_form()
            p["product_id"] = pid
            reorder = req_int("reorder_level", "Reorder level", 0)
            run_transaction([
                ("""UPDATE product SET product_code = %(product_code)s, seller_id = %(seller_id)s,
                           category_id = %(category_id)s, product_name = %(product_name)s,
                           description = %(description)s, unit_price = %(unit_price)s,
                           return_window_days = %(return_window_days)s
                     WHERE product_id = %(product_id)s""", p),
                ("UPDATE inventory SET reorder_level = %s WHERE product_id = %s", (reorder, pid)),
            ])
            flash(f"Product {p['product_code']} updated.", "success")
            return redirect(url_for("products", q=p["product_code"]))
        except ValueError as e:
            flash(str(e), "error")
        except mysql.connector.Error as e:
            flash(friendly_error(e), "error")
        product = {**product, **request.form}
    return render_template("product_form.html", product=product, sellers=sellers,
                           categories=categories, mode="edit", pid=pid)


@app.route("/products/<int:pid>/toggle", methods=["POST"])
def product_toggle(pid):
    # Soft delete: products that appear in orders are never physically deleted
    def act():
        execute("UPDATE product SET is_active = NOT is_active WHERE product_id = %s", (pid,))
    return run_action(act, "Product availability changed.", url_for("products", show="all"))


@app.route("/products/<int:pid>/restock", methods=["POST"])
def product_restock(pid):
    def act():
        qty = req_int("qty", "Restock quantity", 1, 10000)
        execute("UPDATE inventory SET quantity_available = quantity_available + %s WHERE product_id = %s", (qty, pid))
    return run_action(act, "Stock updated.", request.referrer or url_for("products"))


# ----------------------------------------------------------------------
# CUSTOMERS
# ----------------------------------------------------------------------
@app.route("/customers", methods=["GET", "POST"])
def customers():
    if request.method == "POST":
        def act():
            email = req_text("email", "Email", 100).lower()
            if not re.fullmatch(r"[^@\s]+@[^@\s]+\.[^@\s]+", email):
                raise ValueError("Enter a valid email address.")
            phone = req_text("phone", "Phone", 10)
            if not re.fullmatch(r"[6-9]\d{9}", phone):
                raise ValueError("Phone must be a 10-digit mobile number starting with 6-9.")
            pincode = req_text("pincode", "Pincode", 6)
            if not re.fullmatch(r"[1-9]\d{5}", pincode):
                raise ValueError("Pincode must be 6 digits and cannot start with 0.")
            c = (req_text("first_name", "First name", 50), req_text("last_name", "Last name", 50), email, phone)
            a = (req_text("address_line", "Address", 150), req_text("city", "City", 50),
                 req_text("state", "State", 50), pincode)
            # customer, default address and empty cart: one transaction
            run_transaction([
                ("INSERT INTO customer (first_name, last_name, email, phone) VALUES (%s, %s, %s, %s)", c),
                ("SET @new_customer = LAST_INSERT_ID()", ()),
                ("""INSERT INTO address (customer_id, address_line, city, state, pincode, is_default)
                    VALUES (@new_customer, %s, %s, %s, %s, TRUE)""", a),
                ("INSERT INTO cart (customer_id) VALUES (@new_customer)", ()),
            ])
        return run_action(act, "Customer registered.", url_for("customers"))
    q = request.args.get("q", "").strip()
    like = f"%{q}%"
    rows = query("""SELECT c.customer_id, CONCAT(c.first_name, ' ', c.last_name) AS name, c.email, c.phone,
                           a.city, (SELECT COUNT(*) FROM orders o WHERE o.customer_id = c.customer_id) AS orders
                      FROM customer c LEFT JOIN address a ON a.customer_id = c.customer_id AND a.is_default = TRUE
                     WHERE %s = '' OR CONCAT(c.first_name, ' ', c.last_name) LIKE %s OR c.email LIKE %s OR c.phone LIKE %s
                     ORDER BY c.customer_id""", (q, like, like, like))
    return render_template("customers.html", rows=rows, q=q)


# ----------------------------------------------------------------------
# CART AND CHECKOUT
# ----------------------------------------------------------------------
@app.route("/cart")
def cart():
    customers_list = query("SELECT customer_id, CONCAT(first_name, ' ', last_name) AS name FROM customer ORDER BY first_name")
    cid = request.args.get("customer_id", type=int) or (customers_list[0]["customer_id"] if customers_list else None)
    items, addresses, total = [], [], Decimal(0)
    if cid:
        items = query("""SELECT ci.cart_item_id, p.product_id, p.product_code, p.product_name, p.unit_price,
                                ci.quantity, i.quantity_available, ci.quantity * p.unit_price AS line_total
                           FROM cart c JOIN cart_item ci ON ci.cart_id = c.cart_id
                           JOIN product p ON p.product_id = ci.product_id
                           JOIN inventory i ON i.product_id = p.product_id
                          WHERE c.customer_id = %s ORDER BY ci.added_at""", (cid,))
        addresses = query("SELECT * FROM address WHERE customer_id = %s ORDER BY is_default DESC", (cid,))
        total = sum((r["line_total"] for r in items), Decimal(0))
    products_list = query("""SELECT p.product_id, p.product_code, p.product_name, p.unit_price, i.quantity_available
                               FROM product p JOIN inventory i ON i.product_id = p.product_id
                              WHERE p.is_active = TRUE ORDER BY p.product_name""")
    return render_template("cart.html", customers=customers_list, cid=cid, items=items, addresses=addresses,
                           total=total, products=products_list, methods=PAYMENT_METHODS)


@app.route("/cart/add", methods=["POST"])
def cart_add():
    cid = request.form.get("customer_id", type=int)
    def act():
        pid = req_int("product_id", "Product", 1)
        qty = req_int("quantity", "Quantity", 1, 100)
        if not scalar("SELECT is_active FROM product WHERE product_id = %s", (pid,)):
            raise ValueError("This product is not available for sale.")
        run_transaction([
            ("INSERT IGNORE INTO cart (customer_id) VALUES (%s)", (cid,)),
            ("""INSERT INTO cart_item (cart_id, product_id, quantity)
                SELECT cart_id, %s, %s FROM cart WHERE customer_id = %s
                ON DUPLICATE KEY UPDATE quantity = quantity + VALUES(quantity)""", (pid, qty, cid)),
        ])
    return run_action(act, "Added to cart.", url_for("cart", customer_id=cid))


@app.route("/cart/update", methods=["POST"])
def cart_update():
    cid = request.form.get("customer_id", type=int)
    def act():
        item = req_int("cart_item_id", "Cart item", 1)
        qty = req_int("quantity", "Quantity", 0, 100)
        if qty == 0:
            execute("DELETE FROM cart_item WHERE cart_item_id = %s", (item,))
        else:
            execute("UPDATE cart_item SET quantity = %s WHERE cart_item_id = %s", (qty, item))
    return run_action(act, "Cart updated.", url_for("cart", customer_id=cid))


@app.route("/checkout", methods=["POST"])
def checkout():
    cid = request.form.get("customer_id", type=int)
    try:
        aid = req_int("address_id", "Delivery address", 1)
        method = request.form.get("payment_method")
        if method not in PAYMENT_METHODS:
            raise ValueError("Choose a payment method.")
        # The stored procedure runs the whole checkout as ONE transaction
        result = call_procedure("sp_place_order", (cid, aid, method, 0))
        order_id = result[3]
        flash(f"Order placed: ORD-{order_id:06d}. Stock was reserved and the cart emptied.", "success")
        return redirect(url_for("order_detail", oid=order_id))
    except ValueError as e:
        flash(str(e), "error")
    except mysql.connector.Error as e:
        flash("Checkout cancelled, nothing was saved. " + friendly_error(e), "error")
    return redirect(url_for("cart", customer_id=cid))


# ----------------------------------------------------------------------
# ORDER PROCESSING
# ----------------------------------------------------------------------
@app.route("/orders")
def orders():
    status = request.args.get("status", "")
    q = request.args.get("q", "").strip()
    like = f"%{q}%"
    rows = query("""SELECT * FROM v_order_summary
                     WHERE (%s = '' OR order_status = %s)
                       AND (%s = '' OR order_number LIKE %s OR customer_name LIKE %s)
                     ORDER BY order_id DESC""", (status, status, q, like, like))
    return render_template("orders.html", rows=rows, status=status, q=q, statuses=ORDER_STATUSES)


@app.route("/orders/<int:oid>")
def order_detail(oid):
    order = query("""SELECT o.*, CONCAT(c.first_name, ' ', c.last_name) AS customer_name, c.email, c.phone,
                            a.address_line, a.city, a.state, a.pincode
                       FROM orders o JOIN customer c ON c.customer_id = o.customer_id
                       JOIN address a ON a.address_id = o.address_id
                      WHERE o.order_id = %s""", (oid,), one=True)
    if not order:
        flash("Order not found.", "error")
        return redirect(url_for("orders"))
    items = query("""SELECT oi.order_item_id, p.product_code, p.product_name, oi.quantity, oi.unit_price,
                            oi.quantity * oi.unit_price AS line_total, p.return_window_days,
                            COALESCE((SELECT SUM(r.quantity) FROM return_request r
                                       WHERE r.order_item_id = oi.order_item_id AND r.return_status <> 'Rejected'), 0) AS returned
                       FROM order_item oi JOIN product p ON p.product_id = oi.product_id
                      WHERE oi.order_id = %s""", (oid,))
    payment = query("SELECT * FROM payment WHERE order_id = %s", (oid,), one=True)
    shipment = query("SELECT * FROM shipment WHERE order_id = %s", (oid,), one=True)
    returns = query("""SELECT r.*, p.product_name, f.refund_id, f.refund_amount, f.refund_status
                         FROM return_request r JOIN order_item oi ON oi.order_item_id = r.order_item_id
                         JOIN product p ON p.product_id = oi.product_id
                         LEFT JOIN refund f ON f.return_id = r.return_id
                        WHERE oi.order_id = %s ORDER BY r.return_id""", (oid,))
    total = sum((i["line_total"] for i in items), Decimal(0))
    delivered = shipment["delivered_date"] if shipment else None
    for i in items:
        i["return_until"] = delivered + timedelta(days=i["return_window_days"]) if delivered else None
        i["can_return"] = bool(delivered) and i["returned"] < i["quantity"]
    return render_template("order_detail.html", order=order, items=items, payment=payment, shipment=shipment,
                           returns=returns, total=total, couriers=COURIERS)


@app.route("/orders/<int:oid>/status", methods=["POST"])
def order_status(oid):
    new = request.form.get("status")
    def act():
        if new not in ("Confirmed", "Cancelled"):
            raise ValueError("Use the shipment screen to mark an order as shipped or delivered.")
        stmts = [("UPDATE orders SET order_status = %s WHERE order_id = %s", (new, oid))]
        if new == "Cancelled":   # an unpaid COD payment can no longer succeed
            stmts.append(("UPDATE payment SET payment_status = 'Failed' WHERE order_id = %s AND payment_status = 'Pending'", (oid,)))
        run_transaction(stmts)
    msg = "Order cancelled; its stock was returned to inventory." if new == "Cancelled" else "Order confirmed."
    return run_action(act, msg, url_for("order_detail", oid=oid))


@app.route("/orders/<int:oid>/ship", methods=["POST"])
def order_ship(oid):
    def act():
        status = scalar("SELECT order_status FROM orders WHERE order_id = %s", (oid,))
        if status not in ("Placed", "Confirmed"):
            raise ValueError(f"Only placed or confirmed orders can be shipped (this one is {status}).")
        courier = req_text("courier_name", "Courier", 50)
        tracking = req_text("tracking_number", "Tracking number", 30).upper()
        if not re.fullmatch(r"[A-Z0-9]{6,30}", tracking):
            raise ValueError("Tracking number must be 6-30 letters or digits.")
        shipped = req_date("shipped_date", "Shipped date")
        expected = req_date("expected_delivery", "Expected delivery")
        if expected < shipped:
            raise ValueError("Expected delivery cannot be before the shipped date.")
        run_transaction([
            ("""INSERT INTO shipment (order_id, courier_name, tracking_number, shipped_date, expected_delivery, shipment_status)
                VALUES (%s, %s, %s, %s, %s, 'Shipped')""", (oid, courier, tracking, shipped, expected)),
            ("UPDATE orders SET order_status = 'Shipped' WHERE order_id = %s", (oid,)),
        ])
    return run_action(act, "Shipment created; order marked as Shipped.", url_for("order_detail", oid=oid))


# ----------------------------------------------------------------------
# SHIPMENT TRACKING
# ----------------------------------------------------------------------
@app.route("/shipments")
def shipments():
    status = request.args.get("status", "open")
    rows = query("""SELECT s.*, o.order_id, o.order_number, CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
                           a.city
                      FROM shipment s JOIN orders o ON o.order_id = s.order_id
                      JOIN customer c ON c.customer_id = o.customer_id
                      JOIN address a ON a.address_id = o.address_id
                     WHERE %s = 'all' OR (%s = 'open' AND s.shipment_status <> 'Delivered') OR s.shipment_status = %s
                     ORDER BY FIELD(s.shipment_status, 'Pending', 'Shipped', 'In Transit', 'Out for Delivery', 'Delivered'),
                              s.expected_delivery""", (status, status, status))
    return render_template("shipments.html", rows=rows, status=status, flow=SHIPMENT_FLOW)


@app.route("/shipments/<int:sid>/update", methods=["POST"])
def shipment_update(sid):
    def act():
        current = query("SELECT shipment_status, shipped_date FROM shipment WHERE shipment_id = %s", (sid,), one=True)
        if not current:
            raise ValueError("Shipment not found.")
        new = request.form.get("shipment_status")
        if new not in SHIPMENT_FLOW:
            raise ValueError("Choose a valid shipment status.")
        if current["shipment_status"] == "Delivered":
            raise ValueError("This shipment is already delivered.")
        cur_status = current["shipment_status"]
        if cur_status in SHIPMENT_FLOW and SHIPMENT_FLOW.index(new) <= SHIPMENT_FLOW.index(cur_status):
            raise ValueError("A shipment can only move forward (Shipped → In Transit → Out for Delivery → Delivered).")
        if new == "Delivered":
            delivered = req_date("delivered_date", "Delivery date")
            if delivered > date.today():
                raise ValueError("Delivery date cannot be in the future.")
            # trigger trg_shipment_after_update marks the order Delivered
            execute("UPDATE shipment SET shipment_status = 'Delivered', delivered_date = %s WHERE shipment_id = %s",
                    (delivered, sid))
        else:
            execute("UPDATE shipment SET shipment_status = %s WHERE shipment_id = %s", (new, sid))
    return run_action(act, "Shipment status updated.", request.referrer or url_for("shipments"))


# ----------------------------------------------------------------------
# RETURN APPROVAL
# ----------------------------------------------------------------------
@app.route("/returns")
def returns():
    status = request.args.get("status", "")
    rows = query("""SELECT r.return_id, r.quantity, r.reason, r.request_date, r.return_status, r.decided_at,
                           o.order_id, o.order_number, CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
                           p.product_name, oi.unit_price, r.quantity * oi.unit_price AS return_value,
                           f.refund_id, f.refund_status
                      FROM return_request r
                      JOIN order_item oi ON oi.order_item_id = r.order_item_id
                      JOIN orders o      ON o.order_id = oi.order_id
                      JOIN customer c    ON c.customer_id = o.customer_id
                      JOIN product p     ON p.product_id = oi.product_id
                      LEFT JOIN refund f ON f.return_id = r.return_id
                     WHERE %s = '' OR r.return_status = %s
                     ORDER BY r.return_id DESC""", (status, status))
    return render_template("returns.html", rows=rows, status=status, statuses=RETURN_STATUSES)


@app.route("/returns/new", methods=["POST"])
def return_new():
    oid = request.form.get("order_id", type=int)
    def act():
        item = req_int("order_item_id", "Order item", 1)
        qty = req_int("quantity", "Return quantity", 1, 100)
        reason = req_text("reason", "Reason", 200)
        req_on = req_date("request_date", "Request date")
        # trg_return_before_insert checks delivery, the return window and the quantity
        execute("INSERT INTO return_request (order_item_id, quantity, reason, request_date) VALUES (%s, %s, %s, %s)",
                (item, qty, reason, req_on))
    return run_action(act, "Return request created and waiting for approval.", url_for("order_detail", oid=oid))


@app.route("/returns/<int:rid>/decide", methods=["POST"])
def return_decide(rid):
    action = request.form.get("action")
    allowed = {"approve": ("Requested", "Approved"), "reject": ("Requested", "Rejected"), "receive": ("Approved", "Received")}
    def act():
        if action not in allowed:
            raise ValueError("Unknown action.")
        before, after = allowed[action]
        current = scalar("SELECT return_status FROM return_request WHERE return_id = %s", (rid,))
        if current != before:
            raise ValueError(f"Return #{rid} is {current}; it must be {before} to be {after.lower()}.")
        if after == "Received":   # trigger trg_return_after_update puts the units back in stock
            execute("UPDATE return_request SET return_status = 'Received' WHERE return_id = %s", (rid,))
        else:
            execute("UPDATE return_request SET return_status = %s, decided_at = NOW() WHERE return_id = %s", (after, rid))
    return run_action(act, f"Return #{rid} updated.", request.referrer or url_for("returns"))


# ----------------------------------------------------------------------
# REFUND PROCESSING
# ----------------------------------------------------------------------
@app.route("/refunds")
def refunds():
    rows = query("""SELECT f.*, o.order_id, o.order_number, p.product_name, pay.amount AS order_paid, pay.payment_method,
                           r.quantity * oi.unit_price AS return_value
                      FROM refund f JOIN return_request r ON r.return_id = f.return_id
                      JOIN order_item oi ON oi.order_item_id = r.order_item_id
                      JOIN orders o ON o.order_id = oi.order_id
                      JOIN product p ON p.product_id = oi.product_id
                      JOIN payment pay ON pay.order_id = o.order_id
                     ORDER BY f.refund_id DESC""")
    return render_template("refunds.html", rows=rows)


@app.route("/refunds/new", methods=["POST"])
def refund_new():
    def act():
        rid = req_int("return_id", "Return", 1)
        amount = req_money("refund_amount", "Refund amount")
        method = request.form.get("refund_method", "Original Payment")
        if method not in ("Original Payment", "Bank Transfer", "Store Credit"):
            raise ValueError("Choose a refund method.")
        # trg_refund_before_insert checks the return status and the amount paid
        execute("INSERT INTO refund (return_id, refund_amount, refund_method) VALUES (%s, %s, %s)", (rid, amount, method))
    return run_action(act, "Refund initiated.", request.referrer or url_for("refunds"))


@app.route("/refunds/<int:fid>/process", methods=["POST"])
def refund_process(fid):
    def act():
        if scalar("SELECT refund_status FROM refund WHERE refund_id = %s", (fid,)) != "Initiated":
            raise ValueError("Only an initiated refund can be marked as processed.")
        execute("UPDATE refund SET refund_status = 'Processed' WHERE refund_id = %s", (fid,))
    return run_action(act, "Refund marked as processed.", url_for("refunds"))


# ----------------------------------------------------------------------
# REPORTS (the seven SQL views)
# ----------------------------------------------------------------------
REPORTS = {
    "orders":  ("Order status", "SELECT * FROM v_order_status_report ORDER BY FIELD(order_status,'Placed','Confirmed','Shipped','Delivered','Cancelled')"),
    "sellers": ("Seller performance", "SELECT * FROM v_seller_performance ORDER BY net_sales DESC"),
    "stock":   ("Stock", "SELECT * FROM v_stock_status ORDER BY FIELD(stock_status,'Out of stock','Low stock','Discontinued','In stock'), quantity_available"),
    "returns": ("Returns", "SELECT * FROM v_return_report ORDER BY return_id"),
    "refunds": ("Refunds", "SELECT * FROM v_refund_report ORDER BY refund_id"),
    "ratings": ("Product ratings", "SELECT * FROM v_product_ratings ORDER BY avg_rating IS NULL, avg_rating DESC, reviews DESC"),
    "revenue": ("Revenue", "SELECT * FROM v_monthly_revenue ORDER BY month"),
}


@app.route("/reports")
def reports():
    key = request.args.get("r", "orders")
    if key not in REPORTS:
        key = "orders"
    title, sql = REPORTS[key]
    rows = query(sql)
    columns = list(rows[0].keys()) if rows else []
    return render_template("reports.html", reports=REPORTS, key=key, title=title, rows=rows, columns=columns)


if __name__ == "__main__":
    app.run(debug=True)
