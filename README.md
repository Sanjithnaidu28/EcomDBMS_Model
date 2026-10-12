# E-Commerce Order, Return and Refund Management System

DBMS PBL project by **Sanjith Naidu (25WU0101001T)**, B.Tech CSE, Section CSE PANTHERS, Woxsen University.
Faculty: Prof. Sahithi.

A MySQL (MariaDB 10.4, XAMPP) database for a multi-seller online store, with a **Python Flask** application, **ShopDesk**, for catalogue, cart and checkout, orders, shipments, returns, refunds and reports.

## Folder structure

```
EcomDBMS_Final_Project/
├── app.py              Flask routes and input validation
├── db.py               database connection, transactions, error messages
├── config.py           connection settings (host, user, password, database)
├── requirements.txt
├── app/templates/      page templates
├── app/static/         style.css
├── database/           SQL scripts (run in order)
├── docs/               ER diagram, FDs, normalization, data dictionary
├── screenshots/        Workbench and application screenshots
└── tests/test_cases.md
```

## 1. Create the database (MySQL Workbench)

Run each file with the ⚡ button, in this order:

1. `database/01_schema.sql`: database `ecommerce_dbms`, 15 tables, constraints, indexes
2. `database/02_triggers_procedures.sql`: 12 triggers and the checkout procedure `sp_place_order`
3. `database/03_sample_data.sql`: sample data
4. `database/04_views.sql`: 8 report views

`05_queries.sql` (15 queries) and `06_rule_tests.sql` (20 tests) are run one statement at a time (Cmd/Ctrl + Enter).
`07_fix_checkout.sql` is only for databases created with an older copy of file 02; a fresh install does not need it.

## 2. Run the application

1. Start MySQL in XAMPP.
2. If your MySQL `root` user has a password, put it in `DB_PASSWORD` in `config.py`.
3. In a terminal, inside this folder:

```bash
python3 -m pip install -r requirements.txt
python3 app.py
```

4. Open http://127.0.0.1:5000

## Business rules (enforced by the database)

| Rule | Enforced by |
|---|---|
| Order quantity within stock | `trg_orderitem_before_insert`, CHECK `quantity_available >= 0`, `SELECT … FOR UPDATE` in `sp_place_order` |
| At least one item per order | `sp_place_order`, `trg_payment_before_insert`, `trg_orderitem_before_delete`, CHECK `quantity > 0` |
| Valid return period | `trg_return_before_insert` (delivered date + product return window) |
| Refund within paid amount | `trg_refund_before_insert`, `trg_refund_before_update` |
| Unique product codes | UNIQUE `uq_product_code` |

## Reports

Order status, seller performance, stock, returns, refunds, product ratings and monthly revenue: views `v_order_status_report`, `v_seller_performance`, `v_stock_status`, `v_return_report`, `v_refund_report`, `v_product_ratings`, `v_monthly_revenue`.
