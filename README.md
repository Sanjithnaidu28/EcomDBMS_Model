# ShopDesk — E-Commerce Order, Return and Refund Management System

A relational database and web application for a multi-seller online store: product catalogue, inventory, cart and checkout, orders, shipments, returns, refunds, reviews, and management reports.

Built as a DBMS Project-Based Learning project by **Sanjith Naidu (25WU0101001T)**, B.Tech CSE, Section CSE PANTHERS, Woxsen University (Faculty: Prof. Sahithi).

**Stack:** MySQL / MariaDB 10.4 (XAMPP) · Python 3.13 · Flask 3.1 · Jinja2 · mysql-connector-python

## What's in the database

- **15 tables** — customer, address, seller, category, product, inventory, cart, cart_item, orders, order_item, payment, shipment, return_request, refund, review
- **12 triggers** and 1 stored procedure (`sp_place_order`) enforcing five business rules at the database level
- **8 reporting views** for order status, seller performance, stock, returns, refunds, ratings and monthly revenue
- Normalized to 3NF, with primary/foreign/unique/check constraints throughout

## Folder structure

```
.
├── app.py              Flask routes and input validation (24 routes)
├── db.py               database connection, transactions, error translation
├── config.py           connection settings (host, user, password, database)
├── requirements.txt
├── app/templates/       page templates (Jinja2)
├── app/static/          style.css
├── database/             SQL scripts, run in order (see below)
├── docs/                 ER diagram, functional dependencies, normalization, data dictionary
├── screenshots/          MySQL Workbench and application screenshots
└── tests/test_cases.md   application and SQL-level test cases
```

## Setup

### 1. Create the database

Open each script in MySQL Workbench and run the whole file (⚡ button), in this order:

1. `database/01_schema.sql` — creates database `ecommerce_dbms`, 15 tables, constraints, indexes
2. `database/02_triggers_procedures.sql` — 12 triggers and the checkout procedure `sp_place_order`
3. `database/03_sample_data.sql` — sample data
4. `database/04_views.sql` — 8 report views

`05_queries.sql` (15 queries) and `06_rule_tests.sql` (20 rule tests) are meant to be run one statement at a time (Cmd/Ctrl + Enter), not as a whole file.
`07_fix_checkout.sql` is only needed if your database was created from an older copy of file 02 — a fresh install from the files above doesn't need it.

### 2. Run the application

```bash
# Start MySQL in XAMPP first.
# If your MySQL root user has a password, set DB_PASSWORD (or edit config.py).
python3 -m pip install -r requirements.txt
python3 app.py
```

Then open **http://127.0.0.1:5000**

## Business rules enforced by the database

| Rule | Enforced by |
|---|---|
| Order quantity within stock | `trg_orderitem_before_insert`, CHECK `quantity_available >= 0`, `SELECT … FOR UPDATE` in `sp_place_order` |
| At least one item per order | `sp_place_order`, `trg_payment_before_insert`, `trg_orderitem_before_delete`, CHECK `quantity > 0` |
| Valid return period | `trg_return_before_insert` (checks delivery date + product's return window) |
| Refund within paid amount | `trg_refund_before_insert`, `trg_refund_before_update` |
| Unique product codes | UNIQUE constraint `uq_product_code` |

## Reports

Order status, seller performance, stock, returns, refunds, product ratings and monthly revenue — backed by views `v_order_status_report`, `v_seller_performance`, `v_stock_status`, `v_return_report`, `v_refund_report`, `v_product_ratings`, `v_monthly_revenue`.

## Application modules

Dashboard · Catalogue · Customers · Cart & Checkout · Orders · Shipments · Returns · Refunds · Reports
