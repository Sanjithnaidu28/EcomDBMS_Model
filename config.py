"""Database connection settings.
XAMPP's MySQL/MariaDB uses user 'root' with an empty password by default.
If you set a password, put it in DB_PASSWORD below (or set the environment variable)."""
import os

DB_CONFIG = {
    "host": os.getenv("DB_HOST", "127.0.0.1"),
    "port": int(os.getenv("DB_PORT", "3306")),
    "user": os.getenv("DB_USER", "root"),
    "password": os.getenv("DB_PASSWORD", ""),
    "database": os.getenv("DB_NAME", "ecommerce_dbms"),
    # Match MariaDB's default utf8mb4 collation (the one the views were created with);
    # a different connection collation causes "Illegal mix of collations" errors.
    "charset": "utf8mb4",
    "collation": "utf8mb4_general_ci",
    "use_pure": True,
}

SECRET_KEY = os.getenv("SECRET_KEY", "ecommerce-dbms-pbl-demo")

# DEMO_MODE=1 runs the app on the bundled SQLite copy of the database (demo/shopdesk_demo.db)
# instead of MySQL. Used for the hosted live demo, where there is no MySQL server.
DEMO_MODE = os.getenv("DEMO_MODE", "0") == "1"
