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

## Deploying a live demo (Render + Clever Cloud)

The app reads all database settings from environment variables (`config.py`), so it runs unchanged against any MySQL-compatible host — you're not limited to local XAMPP.

### 1. Create a free cloud database (Clever Cloud)

1. Sign up at [clever-cloud.com](https://www.clever-cloud.com/) (free, no card required).
2. Create a new application → **Add-on** → **MySQL** → pick the free **DEV** plan.
3. Open the add-on's **Information** tab and note the host, port, database name, user and password.
4. Load the schema into it from your machine:
   ```bash
   mysql -h <host> -P <port> -u <user> -p <database> < database/00_cloud_setup.sql
   ```
   This is `01_schema.sql` + `02_triggers_procedures.sql` + `03_sample_data.sql` + `04_views.sql` combined into one file, with the `CREATE/DROP DATABASE` and `USE` statements stripped out (a managed add-on already gives you one fixed database and no privilege to create another).

### 2. Deploy the app (Render)

1. Sign up at [render.com](https://render.com/) and connect your GitHub account.
2. **New** → **Web Service** → pick this repository. Render will detect `render.yaml` and pre-fill the build/start commands (`pip install -r requirements.txt` / `gunicorn app:app`).
3. In the service's **Environment** tab, add the values from `.env.example`, filled in with your Clever Cloud credentials: `DB_HOST`, `DB_PORT`, `DB_USER`, `DB_PASSWORD`, `DB_NAME`. Leave `SECRET_KEY` and `FLASK_DEBUG` as Render generates/sets them.
4. Deploy. Render gives you a public `https://<your-service>.onrender.com` URL.

(Free-tier Render services spin down after 15 minutes of inactivity and take ~30–60 seconds to wake back up on the next visit — normal for a demo link, not a bug.)

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
