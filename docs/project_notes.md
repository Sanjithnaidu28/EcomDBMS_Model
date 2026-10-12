# Project Notes

## Reviews
- **Review 1 (Week 7):** problem, scope, objectives, users, functional requirements, business rules, ER diagram, initial schema.
- **Review 2 (Week 11):** functional dependencies, normalization to 3NF, data dictionary, DDL with constraints, triggers, checkout procedure, sample data, queries, views, rule tests.
- **Review 3 (Week 16):** ShopDesk Flask application, live demonstration, test cases, report.

## Environment
- MariaDB 10.4 (MySQL-compatible) via XAMPP, MySQL Workbench
- Python 3.13, Flask 3.1, mysql-connector-python

## Notes
- XAMPP's MariaDB had to be upgraded once with `mysql_upgrade` before triggers could be created (error 1558).
- The connection collation is `utf8mb4_general_ci` to match MariaDB's default (otherwise error 1267 on views).
- The checkout procedure copies only from `cart_item` when inserting order items, so the stock trigger can lock `inventory` (fix for error 1442, file 07).
