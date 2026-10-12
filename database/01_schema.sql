-- =====================================================================
-- E-Commerce Order, Return and Refund Management System
-- File 01: Database and tables (DDL)            Target: MySQL 8.0.16+
-- Author : Sanjith Naidu (25WU0101001T)
-- Run order: 01_schema -> 02_triggers_procedures -> 03_sample_data
--            -> 04_views -> 05_queries -> 06_rule_tests
-- =====================================================================

DROP DATABASE IF EXISTS ecommerce_dbms;
CREATE DATABASE ecommerce_dbms CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE ecommerce_dbms;

-- ---------------------------------------------------------------------
-- PEOPLE
-- ---------------------------------------------------------------------
CREATE TABLE customer (
    customer_id   INT           AUTO_INCREMENT PRIMARY KEY,
    first_name    VARCHAR(50)   NOT NULL,
    last_name     VARCHAR(50)   NOT NULL,
    email         VARCHAR(100)  NOT NULL,
    phone         CHAR(10)      NOT NULL,
    created_at    DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_customer_email UNIQUE (email),
    CONSTRAINT uq_customer_phone UNIQUE (phone),
    CONSTRAINT chk_customer_email CHECK (email LIKE '%_@_%._%'),
    CONSTRAINT chk_customer_phone CHECK (phone REGEXP '^[6-9][0-9]{9}$')
);

CREATE TABLE address (
    address_id    INT           AUTO_INCREMENT PRIMARY KEY,
    customer_id   INT           NOT NULL,
    address_line  VARCHAR(150)  NOT NULL,
    city          VARCHAR(50)   NOT NULL,
    state         VARCHAR(50)   NOT NULL,
    pincode       CHAR(6)       NOT NULL,
    is_default    BOOLEAN       NOT NULL DEFAULT FALSE,
    CONSTRAINT fk_address_customer FOREIGN KEY (customer_id) REFERENCES customer(customer_id),
    CONSTRAINT chk_address_pincode CHECK (pincode REGEXP '^[1-9][0-9]{5}$')
);

CREATE TABLE seller (
    seller_id     INT           AUTO_INCREMENT PRIMARY KEY,
    store_name    VARCHAR(100)  NOT NULL,
    contact_name  VARCHAR(100)  NOT NULL,
    email         VARCHAR(100)  NOT NULL,
    phone         CHAR(10)      NOT NULL,
    gstin         CHAR(15)      NOT NULL,
    city          VARCHAR(50)   NOT NULL,
    joined_on     DATE          NOT NULL DEFAULT (CURRENT_DATE),
    CONSTRAINT uq_seller_store UNIQUE (store_name),
    CONSTRAINT uq_seller_email UNIQUE (email),
    CONSTRAINT uq_seller_gstin UNIQUE (gstin),
    CONSTRAINT chk_seller_email CHECK (email LIKE '%_@_%._%'),
    CONSTRAINT chk_seller_phone CHECK (phone REGEXP '^[6-9][0-9]{9}$'),
    CONSTRAINT chk_seller_gstin CHECK (CHAR_LENGTH(gstin) = 15)
);

-- ---------------------------------------------------------------------
-- CATALOGUE
-- ---------------------------------------------------------------------
CREATE TABLE category (
    category_id         INT          AUTO_INCREMENT PRIMARY KEY,
    category_name       VARCHAR(60)  NOT NULL,
    parent_category_id  INT          NULL,
    CONSTRAINT uq_category_name UNIQUE (category_name),
    CONSTRAINT fk_category_parent FOREIGN KEY (parent_category_id) REFERENCES category(category_id)
);

CREATE TABLE product (
    product_id          INT            AUTO_INCREMENT PRIMARY KEY,
    product_code        VARCHAR(20)    NOT NULL,
    seller_id           INT            NOT NULL,
    category_id         INT            NOT NULL,
    product_name        VARCHAR(120)   NOT NULL,
    description         VARCHAR(500)   NULL,
    unit_price          DECIMAL(10,2)  NOT NULL,
    return_window_days  INT            NOT NULL DEFAULT 7,
    is_active           BOOLEAN        NOT NULL DEFAULT TRUE,
    created_at          DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_product_code UNIQUE (product_code),                 -- Business rule 5
    CONSTRAINT fk_product_seller   FOREIGN KEY (seller_id)   REFERENCES seller(seller_id),
    CONSTRAINT fk_product_category FOREIGN KEY (category_id) REFERENCES category(category_id),
    CONSTRAINT chk_product_price  CHECK (unit_price > 0),
    CONSTRAINT chk_product_window CHECK (return_window_days BETWEEN 0 AND 30)
);

CREATE TABLE inventory (
    inventory_id        INT       AUTO_INCREMENT PRIMARY KEY,
    product_id          INT       NOT NULL,
    quantity_available  INT       NOT NULL DEFAULT 0,
    reorder_level       INT       NOT NULL DEFAULT 5,
    last_updated        DATETIME  NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT uq_inventory_product UNIQUE (product_id),             -- 1 : 1 with product
    CONSTRAINT fk_inventory_product FOREIGN KEY (product_id) REFERENCES product(product_id),
    CONSTRAINT chk_inventory_qty     CHECK (quantity_available >= 0), -- Business rule 1 (last line of defence)
    CONSTRAINT chk_inventory_reorder CHECK (reorder_level >= 0)
);

-- ---------------------------------------------------------------------
-- SHOPPING
-- ---------------------------------------------------------------------
CREATE TABLE cart (
    cart_id      INT       AUTO_INCREMENT PRIMARY KEY,
    customer_id  INT       NOT NULL,
    created_at   DATETIME  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_cart_customer UNIQUE (customer_id),                 -- one cart per customer
    CONSTRAINT fk_cart_customer FOREIGN KEY (customer_id) REFERENCES customer(customer_id) ON DELETE CASCADE
);

CREATE TABLE cart_item (
    cart_item_id  INT       AUTO_INCREMENT PRIMARY KEY,
    cart_id       INT       NOT NULL,
    product_id    INT       NOT NULL,
    quantity      INT       NOT NULL DEFAULT 1,
    added_at      DATETIME  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_cart_product UNIQUE (cart_id, product_id),
    CONSTRAINT fk_cartitem_cart    FOREIGN KEY (cart_id)    REFERENCES cart(cart_id) ON DELETE CASCADE,
    CONSTRAINT fk_cartitem_product FOREIGN KEY (product_id) REFERENCES product(product_id),
    CONSTRAINT chk_cartitem_qty CHECK (quantity > 0)
);

CREATE TABLE orders (
    order_id      INT          AUTO_INCREMENT PRIMARY KEY,
    order_number  VARCHAR(50)  NOT NULL,
    customer_id   INT          NOT NULL,
    address_id    INT          NOT NULL,
    order_date    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    order_status  VARCHAR(20)  NOT NULL DEFAULT 'Placed',
    CONSTRAINT uq_order_number UNIQUE (order_number),
    CONSTRAINT fk_order_customer FOREIGN KEY (customer_id) REFERENCES customer(customer_id),
    CONSTRAINT fk_order_address  FOREIGN KEY (address_id)  REFERENCES address(address_id),
    CONSTRAINT chk_order_status CHECK (order_status IN ('Placed','Confirmed','Shipped','Delivered','Cancelled'))
);

CREATE TABLE order_item (
    order_item_id  INT            AUTO_INCREMENT PRIMARY KEY,
    order_id       INT            NOT NULL,
    product_id     INT            NOT NULL,
    quantity       INT            NOT NULL,
    unit_price     DECIMAL(10,2)  NOT NULL,          -- price at the time of ordering
    CONSTRAINT uq_order_product UNIQUE (order_id, product_id),
    CONSTRAINT fk_orderitem_order   FOREIGN KEY (order_id)   REFERENCES orders(order_id),
    CONSTRAINT fk_orderitem_product FOREIGN KEY (product_id) REFERENCES product(product_id),
    CONSTRAINT chk_orderitem_qty   CHECK (quantity > 0),  -- Business rule 2 (each item at least 1 unit)
    CONSTRAINT chk_orderitem_price CHECK (unit_price > 0)
);

-- ---------------------------------------------------------------------
-- FULFILMENT
-- ---------------------------------------------------------------------
CREATE TABLE payment (
    payment_id       INT            AUTO_INCREMENT PRIMARY KEY,
    order_id         INT            NOT NULL,
    amount           DECIMAL(10,2)  NOT NULL,
    payment_method   VARCHAR(20)    NOT NULL,
    payment_status   VARCHAR(20)    NOT NULL DEFAULT 'Pending',
    transaction_ref  VARCHAR(40)    NOT NULL,
    paid_at          DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_payment_order UNIQUE (order_id),                    -- 1 : 1 with orders
    CONSTRAINT uq_payment_txn   UNIQUE (transaction_ref),
    CONSTRAINT fk_payment_order FOREIGN KEY (order_id) REFERENCES orders(order_id),
    CONSTRAINT chk_payment_amount CHECK (amount > 0),
    CONSTRAINT chk_payment_method CHECK (payment_method IN ('UPI','Card','NetBanking','COD')),
    CONSTRAINT chk_payment_status CHECK (payment_status IN ('Pending','Success','Failed'))
);

CREATE TABLE shipment (
    shipment_id        INT          AUTO_INCREMENT PRIMARY KEY,
    order_id           INT          NOT NULL,
    courier_name       VARCHAR(50)  NOT NULL,
    tracking_number    VARCHAR(30)  NOT NULL,
    shipped_date       DATE         NULL,
    expected_delivery  DATE         NULL,
    delivered_date     DATE         NULL,
    shipment_status    VARCHAR(20)  NOT NULL DEFAULT 'Pending',
    CONSTRAINT uq_shipment_order    UNIQUE (order_id),                -- 1 : 1 with orders
    CONSTRAINT uq_shipment_tracking UNIQUE (tracking_number),
    CONSTRAINT fk_shipment_order FOREIGN KEY (order_id) REFERENCES orders(order_id),
    CONSTRAINT chk_shipment_status CHECK (shipment_status IN ('Pending','Shipped','In Transit','Out for Delivery','Delivered')),
    CONSTRAINT chk_shipment_expected  CHECK (expected_delivery IS NULL OR shipped_date IS NULL OR expected_delivery >= shipped_date),
    CONSTRAINT chk_shipment_delivered CHECK (delivered_date IS NULL OR (shipped_date IS NOT NULL AND delivered_date >= shipped_date)),
    CONSTRAINT chk_shipment_done      CHECK ((shipment_status = 'Delivered') = (delivered_date IS NOT NULL))
);

-- ---------------------------------------------------------------------
-- AFTER-SALES
-- ---------------------------------------------------------------------
CREATE TABLE return_request (
    return_id      INT           AUTO_INCREMENT PRIMARY KEY,
    order_item_id  INT           NOT NULL,
    quantity       INT           NOT NULL DEFAULT 1,
    reason         VARCHAR(200)  NOT NULL,
    request_date   DATE          NOT NULL DEFAULT (CURRENT_DATE),
    return_status  VARCHAR(20)   NOT NULL DEFAULT 'Requested',
    decided_at     DATETIME      NULL,
    CONSTRAINT fk_return_orderitem FOREIGN KEY (order_item_id) REFERENCES order_item(order_item_id),
    CONSTRAINT chk_return_qty    CHECK (quantity > 0),
    CONSTRAINT chk_return_status CHECK (return_status IN ('Requested','Approved','Rejected','Received'))
);

CREATE TABLE refund (
    refund_id      INT            AUTO_INCREMENT PRIMARY KEY,
    return_id      INT            NOT NULL,
    refund_amount  DECIMAL(10,2)  NOT NULL,
    refund_method  VARCHAR(20)    NOT NULL DEFAULT 'Original Payment',
    refund_status  VARCHAR(20)    NOT NULL DEFAULT 'Initiated',
    initiated_at   DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    processed_at   DATETIME       NULL,
    CONSTRAINT uq_refund_return UNIQUE (return_id),                   -- 1 : 1 with return_request
    CONSTRAINT fk_refund_return FOREIGN KEY (return_id) REFERENCES return_request(return_id),
    CONSTRAINT chk_refund_amount CHECK (refund_amount > 0),
    CONSTRAINT chk_refund_method CHECK (refund_method IN ('Original Payment','Bank Transfer','Store Credit')),
    CONSTRAINT chk_refund_status CHECK (refund_status IN ('Initiated','Processed','Failed'))
);

CREATE TABLE review (
    review_id    INT           AUTO_INCREMENT PRIMARY KEY,
    customer_id  INT           NOT NULL,
    product_id   INT           NOT NULL,
    rating       TINYINT       NOT NULL,
    comment      VARCHAR(500)  NULL,
    review_date  DATE          NOT NULL DEFAULT (CURRENT_DATE),
    CONSTRAINT uq_review_customer_product UNIQUE (customer_id, product_id),
    CONSTRAINT fk_review_customer FOREIGN KEY (customer_id) REFERENCES customer(customer_id),
    CONSTRAINT fk_review_product  FOREIGN KEY (product_id)  REFERENCES product(product_id),
    CONSTRAINT chk_review_rating CHECK (rating BETWEEN 1 AND 5)
);

-- ---------------------------------------------------------------------
-- INDEXES on frequently searched attributes
-- (PK, UNIQUE and FK columns are indexed automatically by MySQL)
-- ---------------------------------------------------------------------
CREATE INDEX idx_product_name     ON product (product_name);
CREATE INDEX idx_product_active   ON product (is_active, category_id);
CREATE INDEX idx_customer_name    ON customer (last_name, first_name);
CREATE INDEX idx_order_status     ON orders (order_status);
CREATE INDEX idx_order_date       ON orders (order_date);
CREATE INDEX idx_shipment_status  ON shipment (shipment_status);
CREATE INDEX idx_return_status    ON return_request (return_status);
CREATE INDEX idx_refund_status    ON refund (refund_status);
CREATE INDEX idx_payment_status   ON payment (payment_status);

SHOW TABLES;
