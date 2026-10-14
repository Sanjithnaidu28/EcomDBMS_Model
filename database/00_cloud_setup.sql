-- =====================================================================
-- E-Commerce Order, Return and Refund Management System
-- Cloud setup script (for Clever Cloud / Render deployment)
-- Combines 01_schema + 02_triggers_procedures + 03_sample_data + 04_views
-- into one file, with the DROP/CREATE DATABASE and USE statements removed
-- since a managed MySQL add-on already gives you one fixed database and
-- no CREATE/DROP DATABASE privilege. Run with:
--   mysql -h HOST -P PORT -u USER -p DBNAME < 00_cloud_setup.sql
-- Author: Sanjith Naidu (25WU0101001T)
-- =====================================================================

-- ===== from 01_schema.sql =====
-- =====================================================================
-- E-Commerce Order, Return and Refund Management System
-- File 01: Database and tables (DDL)            Target: MySQL 8.0.16+
-- Author : Sanjith Naidu (25WU0101001T)
-- Run order: 01_schema -> 02_triggers_procedures -> 03_sample_data
--            -> 04_views -> 05_queries -> 06_rule_tests
-- =====================================================================


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


-- ===== from 02_triggers_procedures.sql =====
-- =====================================================================
-- File 02: Triggers and stored procedure that enforce the business rules
--   Rule 1  Order quantity within stock     -> trg_orderitem_before_insert, trg_orderitem_after_insert,
--                                              CHECK (quantity_available >= 0), sp_place_order (FOR UPDATE)
--   Rule 2  At least one item per order     -> trg_payment_before_insert, trg_orderitem_before_delete,
--                                              trg_order_before_update, sp_place_order (empty-cart check)
--   Rule 3  Valid return period             -> trg_return_before_insert
--   Rule 4  Refund within paid amount       -> trg_refund_before_insert, trg_refund_before_update
--   Rule 5  Unique product codes            -> UNIQUE constraint uq_product_code (file 01)
-- In MySQL Workbench run the whole file with the lightning-bolt button.
-- =====================================================================

DROP TRIGGER IF EXISTS trg_orderitem_before_insert;
DROP TRIGGER IF EXISTS trg_orderitem_after_insert;
DROP TRIGGER IF EXISTS trg_orderitem_before_delete;
DROP TRIGGER IF EXISTS trg_order_before_update;
DROP TRIGGER IF EXISTS trg_order_after_update;
DROP TRIGGER IF EXISTS trg_payment_before_insert;
DROP TRIGGER IF EXISTS trg_shipment_after_update;
DROP TRIGGER IF EXISTS trg_return_before_insert;
DROP TRIGGER IF EXISTS trg_return_after_update;
DROP TRIGGER IF EXISTS trg_refund_before_insert;
DROP TRIGGER IF EXISTS trg_refund_before_update;
DROP TRIGGER IF EXISTS trg_review_before_insert;
DROP PROCEDURE IF EXISTS sp_place_order;

DELIMITER $$

-- ---------------------------------------------------------------------
-- RULE 1: an order item cannot ask for more units than are in stock.
-- Also copies the current product price into the order item if not given,
-- and refuses inactive products.
-- ---------------------------------------------------------------------
CREATE TRIGGER trg_orderitem_before_insert
BEFORE INSERT ON order_item
FOR EACH ROW
BEGIN
    DECLARE v_stock  INT;
    DECLARE v_price  DECIMAL(10,2);
    DECLARE v_active BOOLEAN;
    DECLARE v_status VARCHAR(20);

    SELECT order_status INTO v_status FROM orders WHERE order_id = NEW.order_id;
    IF v_status IN ('Shipped','Delivered','Cancelled') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Items cannot be added to an order that is shipped, delivered or cancelled.';
    END IF;

    -- product details: a plain read
    SELECT unit_price, is_active INTO v_price, v_active
      FROM product WHERE product_id = NEW.product_id;

    -- stock row: locked so two orders cannot take the same last unit
    SELECT quantity_available INTO v_stock
      FROM inventory WHERE product_id = NEW.product_id
       FOR UPDATE;

    IF v_active IS NULL OR v_active = FALSE THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Product is not available for sale.';
    END IF;

    IF NEW.quantity > v_stock THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Order quantity exceeds available stock.';
    END IF;

    IF NEW.unit_price IS NULL OR NEW.unit_price = 0 THEN
        SET NEW.unit_price = v_price;
    END IF;
END$$

-- After the item is saved, take the units out of stock.
CREATE TRIGGER trg_orderitem_after_insert
AFTER INSERT ON order_item
FOR EACH ROW
BEGIN
    UPDATE inventory
       SET quantity_available = quantity_available - NEW.quantity
     WHERE product_id = NEW.product_id;
END$$

-- ---------------------------------------------------------------------
-- RULE 2: an order must always keep at least one item.
-- ---------------------------------------------------------------------
CREATE TRIGGER trg_orderitem_before_delete
BEFORE DELETE ON order_item
FOR EACH ROW
BEGIN
    IF (SELECT COUNT(*) FROM order_item WHERE order_id = OLD.order_id) <= 1 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'An order must contain at least one item. Cancel the order instead.';
    END IF;
END$$

-- An order cannot move past "Placed" unless it has at least one item,
-- and a cancelled or delivered order cannot change status again.
CREATE TRIGGER trg_order_before_update
BEFORE UPDATE ON orders
FOR EACH ROW
BEGIN
    IF NEW.order_status <> OLD.order_status THEN
        IF OLD.order_status IN ('Cancelled','Delivered') THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'A cancelled or delivered order cannot change status.';
        END IF;
        IF NEW.order_status = 'Cancelled' AND OLD.order_status = 'Shipped' THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'A shipped order cannot be cancelled; raise a return after delivery.';
        END IF;
        IF NEW.order_status <> 'Cancelled'
           AND (SELECT COUNT(*) FROM order_item WHERE order_id = NEW.order_id) = 0 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'An order must contain at least one item.';
        END IF;
    END IF;
END$$

-- When an order is cancelled, put its units back into stock.
CREATE TRIGGER trg_order_after_update
AFTER UPDATE ON orders
FOR EACH ROW
BEGIN
    IF NEW.order_status = 'Cancelled' AND OLD.order_status <> 'Cancelled' THEN
        UPDATE inventory i
          JOIN order_item oi ON oi.product_id = i.product_id
           SET i.quantity_available = i.quantity_available + oi.quantity
         WHERE oi.order_id = NEW.order_id;
    END IF;
END$$

-- A payment can only be recorded for an order that has items,
-- and its amount must equal the order total.
CREATE TRIGGER trg_payment_before_insert
BEFORE INSERT ON payment
FOR EACH ROW
BEGIN
    DECLARE v_items INT;
    DECLARE v_total DECIMAL(10,2);

    SELECT COUNT(*), COALESCE(SUM(quantity * unit_price), 0)
      INTO v_items, v_total
      FROM order_item WHERE order_id = NEW.order_id;

    IF v_items = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cannot record a payment for an order with no items.';
    END IF;
    IF NEW.amount <> v_total THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Payment amount must equal the order total.';
    END IF;
END$$

-- Keep the order status in step with the shipment status.
CREATE TRIGGER trg_shipment_after_update
AFTER UPDATE ON shipment
FOR EACH ROW
BEGIN
    IF NEW.shipment_status <> OLD.shipment_status THEN
        IF NEW.shipment_status = 'Delivered' THEN
            UPDATE orders SET order_status = 'Delivered' WHERE order_id = NEW.order_id;
        ELSEIF NEW.shipment_status IN ('Shipped','In Transit','Out for Delivery') THEN
            UPDATE orders SET order_status = 'Shipped'
             WHERE order_id = NEW.order_id AND order_status IN ('Placed','Confirmed');
        END IF;
    END IF;
END$$

-- ---------------------------------------------------------------------
-- RULE 3: a return is accepted only after delivery and within the
-- product's return window; the quantity cannot exceed what was bought
-- minus what is already being returned.
-- ---------------------------------------------------------------------
CREATE TRIGGER trg_return_before_insert
BEFORE INSERT ON return_request
FOR EACH ROW
BEGIN
    DECLARE v_delivered DATE;
    DECLARE v_window    INT;
    DECLARE v_bought    INT;
    DECLARE v_returned  INT;

    SELECT s.delivered_date, p.return_window_days, oi.quantity
      INTO v_delivered, v_window, v_bought
      FROM order_item oi
      JOIN product p        ON p.product_id = oi.product_id
      LEFT JOIN shipment s  ON s.order_id   = oi.order_id
     WHERE oi.order_item_id = NEW.order_item_id;

    IF v_delivered IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Return not allowed: the order has not been delivered yet.';
    END IF;
    IF NEW.request_date < v_delivered THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Return date cannot be before the delivery date.';
    END IF;
    IF NEW.request_date > DATE_ADD(v_delivered, INTERVAL v_window DAY) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Return not allowed: the return period for this product has ended.';
    END IF;

    SELECT COALESCE(SUM(quantity), 0) INTO v_returned
      FROM return_request
     WHERE order_item_id = NEW.order_item_id AND return_status <> 'Rejected';

    IF NEW.quantity + v_returned > v_bought THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Return quantity exceeds the quantity purchased.';
    END IF;
END$$

-- When returned goods are received back, add them to stock again.
CREATE TRIGGER trg_return_after_update
AFTER UPDATE ON return_request
FOR EACH ROW
BEGIN
    IF NEW.return_status = 'Received' AND OLD.return_status <> 'Received' THEN
        UPDATE inventory i
          JOIN order_item oi ON oi.product_id = i.product_id
           SET i.quantity_available = i.quantity_available + NEW.quantity
         WHERE oi.order_item_id = NEW.order_item_id;
    END IF;
END$$

-- ---------------------------------------------------------------------
-- RULE 4: a refund cannot exceed (a) the value of the returned units and
-- (b) together with earlier refunds, the amount actually paid for the order.
-- ---------------------------------------------------------------------
CREATE TRIGGER trg_refund_before_insert
BEFORE INSERT ON refund
FOR EACH ROW
BEGIN
    DECLARE v_status     VARCHAR(20);
    DECLARE v_item_value DECIMAL(10,2);
    DECLARE v_order      INT;
    DECLARE v_paid       DECIMAL(10,2);
    DECLARE v_refunded   DECIMAL(10,2);

    SELECT r.return_status, r.quantity * oi.unit_price, oi.order_id
      INTO v_status, v_item_value, v_order
      FROM return_request r JOIN order_item oi ON oi.order_item_id = r.order_item_id
     WHERE r.return_id = NEW.return_id;

    IF v_status NOT IN ('Approved','Received') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Refund allowed only for an approved or received return.';
    END IF;

    SELECT amount INTO v_paid FROM payment
     WHERE order_id = v_order AND payment_status = 'Success';
    IF v_paid IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'No successful payment found for this order.';
    END IF;

    IF NEW.refund_amount > v_item_value THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Refund exceeds the value of the returned items.';
    END IF;

    SELECT COALESCE(SUM(f.refund_amount), 0) INTO v_refunded
      FROM refund f
      JOIN return_request r ON r.return_id = f.return_id
      JOIN order_item oi    ON oi.order_item_id = r.order_item_id
     WHERE oi.order_id = v_order AND f.refund_status <> 'Failed';

    IF v_refunded + NEW.refund_amount > v_paid THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Total refunds exceed the amount paid for the order.';
    END IF;
END$$

CREATE TRIGGER trg_refund_before_update
BEFORE UPDATE ON refund
FOR EACH ROW
BEGIN
    DECLARE v_item_value DECIMAL(10,2);
    IF NEW.refund_amount <> OLD.refund_amount THEN
        SELECT r.quantity * oi.unit_price INTO v_item_value
          FROM return_request r JOIN order_item oi ON oi.order_item_id = r.order_item_id
         WHERE r.return_id = NEW.return_id;
        IF NEW.refund_amount > v_item_value THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Refund exceeds the value of the returned items.';
        END IF;
    END IF;
    IF NEW.refund_status = 'Processed' AND NEW.processed_at IS NULL THEN
        SET NEW.processed_at = NOW();
    END IF;
END$$

-- A customer can review only a product they have received.
CREATE TRIGGER trg_review_before_insert
BEFORE INSERT ON review
FOR EACH ROW
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM orders o JOIN order_item oi ON oi.order_id = o.order_id
         WHERE o.customer_id = NEW.customer_id
           AND oi.product_id = NEW.product_id
           AND o.order_status = 'Delivered') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Only customers who received this product can review it.';
    END IF;
END$$

-- ---------------------------------------------------------------------
-- CHECKOUT as ONE TRANSACTION (Rules 1 and 2).
-- Converts the customer's cart into an order, locks the stock rows,
-- creates the order items (triggers check and reduce stock), records the
-- payment and empties the cart. Any error rolls everything back.
-- ---------------------------------------------------------------------
CREATE PROCEDURE sp_place_order(
    IN  p_customer_id INT,
    IN  p_address_id  INT,
    IN  p_method      VARCHAR(20),
    OUT p_order_id    INT)
BEGIN
    DECLARE v_cart  INT;
    DECLARE v_items INT;
    DECLARE v_total DECIMAL(10,2);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    SELECT cart_id INTO v_cart FROM cart WHERE customer_id = p_customer_id;
    SELECT COUNT(*) INTO v_items FROM cart_item WHERE cart_id = v_cart;
    IF v_cart IS NULL OR v_items = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cart is empty: an order needs at least one item.';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM address WHERE address_id = p_address_id AND customer_id = p_customer_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Delivery address does not belong to this customer.';
    END IF;

    -- lock the stock rows of every product in the cart
    SELECT COUNT(*) INTO v_items FROM inventory i
      JOIN cart_item ci ON ci.product_id = i.product_id
     WHERE ci.cart_id = v_cart
       FOR UPDATE;

    INSERT INTO orders (order_number, customer_id, address_id, order_status)
    VALUES (CONCAT('TMP-', UUID()), p_customer_id, p_address_id, 'Placed');
    SET p_order_id = LAST_INSERT_ID();
    UPDATE orders SET order_number = CONCAT('ORD-', LPAD(p_order_id, 6, '0')) WHERE order_id = p_order_id;

    -- unit_price 0 = "use the current price": the trigger fills it in.
    -- (This statement reads only cart_item, so the triggers are free to
    --  read product and update inventory.)
    INSERT INTO order_item (order_id, product_id, quantity, unit_price)
    SELECT p_order_id, ci.product_id, ci.quantity, 0
      FROM cart_item ci
     WHERE ci.cart_id = v_cart;

    SELECT SUM(quantity * unit_price) INTO v_total FROM order_item WHERE order_id = p_order_id;

    INSERT INTO payment (order_id, amount, payment_method, payment_status, transaction_ref)
    VALUES (p_order_id, v_total, p_method,
            IF(p_method = 'COD', 'Pending', 'Success'),
            CONCAT('TXN-', LPAD(p_order_id, 6, '0'), '-', UPPER(LEFT(REPLACE(UUID(), '-', ''), 6))));

    UPDATE orders SET order_status = 'Confirmed' WHERE order_id = p_order_id;

    DELETE FROM cart_item WHERE cart_id = v_cart;

    COMMIT;
END$$

DELIMITER ;

SHOW TRIGGERS;


-- ===== from 03_sample_data.sql =====
-- =====================================================================
-- File 03: Realistic sample data (Indian e-commerce context)
-- Generated so that every row satisfies the triggers in file 02.
-- Inserts follow the real workflow: order -> items -> payment ->
-- shipment -> status updates -> returns -> refunds -> reviews.
-- =====================================================================

-- Sellers
INSERT INTO seller (seller_id, store_name, contact_name, email, phone, gstin, city, joined_on) VALUES
(1, 'TechNest Electronics', 'Ravi Kumar', 'sales@technest.in', '9848012345', '36AABCT1234F1Z5', 'Hyderabad', '2026-01-12'),
(2, 'UrbanThreads Fashion', 'Priya Sharma', 'hello@urbanthreads.in', '9886023456', '29AACCU5678K1Z2', 'Bengaluru', '2026-02-03'),
(3, 'HomeKraft Living', 'Arjun Mehta', 'care@homekraft.in', '9822034567', '27AAFCH9012L1Z8', 'Pune', '2026-02-20'),
(4, 'PageTurner Books', 'Neha Iyer', 'orders@pageturner.in', '9840045678', '33AAGCP3456M1Z1', 'Chennai', '2026-03-15'),
(5, 'FitFuel Sports', 'Karan Reddy', 'support@fitfuel.in', '9819056789', '27AAHCF7890N1Z4', 'Mumbai', '2026-04-01');

-- Categories (parents first, then sub-categories)
INSERT INTO category (category_id, category_name, parent_category_id) VALUES
(1, 'Electronics', NULL),
(2, 'Fashion', NULL),
(3, 'Home & Kitchen', NULL),
(4, 'Books', NULL),
(5, 'Sports & Fitness', NULL),
(6, 'Mobiles', 1),
(7, 'Audio', 1),
(8, 'Laptop Accessories', 1),
(9, 'Men''s Clothing', 2),
(10, 'Footwear', 2),
(11, 'Kitchen Appliances', 3),
(12, 'Fiction', 4),
(13, 'Fitness Equipment', 5);

-- Products
INSERT INTO product (product_id, product_code, seller_id, category_id, product_name, description, unit_price, return_window_days, is_active) VALUES
(1, 'TN-MOB-001', 1, 6, 'Redmi Note 13 5G (128 GB)', '6.67-inch AMOLED, 5000 mAh battery', 18999.00, 7, TRUE),
(2, 'TN-MOB-002', 1, 6, 'Samsung Galaxy M35 5G', '6.6-inch display, 6000 mAh battery', 16499.00, 7, TRUE),
(3, 'TN-AUD-001', 1, 7, 'boAt Rockerz 450 Headphones', 'Wireless on-ear, 15 h playback', 1499.00, 7, TRUE),
(4, 'TN-AUD-002', 1, 7, 'JBL Tune 230NC Earbuds', 'Active noise cancelling TWS earbuds', 4999.00, 7, TRUE),
(5, 'TN-ACC-001', 1, 8, 'Logitech M331 Silent Mouse', 'Wireless silent-click mouse', 1295.00, 10, TRUE),
(6, 'TN-ACC-002', 1, 8, 'Portronics Laptop Stand', 'Adjustable aluminium stand', 999.00, 10, TRUE),
(7, 'UT-MEN-001', 2, 9, 'Cotton Slim Fit Shirt', '100% cotton, full sleeves', 899.00, 15, TRUE),
(8, 'UT-MEN-002', 2, 9, 'Men''s Denim Jeans', 'Stretchable slim-fit denim', 1499.00, 15, TRUE),
(9, 'UT-FTW-001', 2, 10, 'Running Shoes (Men)', 'Lightweight mesh running shoes', 2499.00, 15, TRUE),
(10, 'UT-FTW-002', 2, 10, 'Casual Sneakers (Women)', 'Canvas lace-up sneakers', 1999.00, 15, TRUE),
(11, 'HK-KIT-001', 3, 11, 'Prestige Mixer Grinder 750W', '3 jars, 750 W motor', 3299.00, 10, TRUE),
(12, 'HK-KIT-002', 3, 11, 'Pigeon Electric Kettle 1.5 L', 'Stainless steel, auto cut-off', 799.00, 10, TRUE),
(13, 'HK-KIT-003', 3, 3, 'Non-stick Cookware Set (3 pc)', 'Induction base, PFOA free', 1899.00, 10, TRUE),
(14, 'PT-FIC-001', 4, 12, 'The Alchemist (Paperback)', 'Paulo Coelho', 299.00, 7, TRUE),
(15, 'PT-BKS-002', 4, 4, 'Atomic Habits (Paperback)', 'James Clear', 499.00, 7, TRUE),
(16, 'PT-BKS-003', 4, 4, 'Wings of Fire (Paperback)', 'A. P. J. Abdul Kalam', 349.00, 7, TRUE),
(17, 'FF-FIT-001', 5, 13, 'Yoga Mat 6 mm', 'Anti-slip TPE mat', 699.00, 7, TRUE),
(18, 'FF-FIT-002', 5, 13, 'Adjustable Dumbbells 10 kg Pair', 'Chrome-plated, with case', 2799.00, 7, TRUE),
(19, 'FF-FIT-003', 5, 13, 'Skipping Rope with Counter', 'Digital counter, adjustable', 349.00, 7, TRUE),
(20, 'FF-SPT-001', 5, 5, 'Cricket Bat (Kashmir Willow)', 'Full size, discontinued model', 1599.00, 7, FALSE);

-- Opening stock (order items below reduce it automatically through the trigger)
INSERT INTO inventory (product_id, quantity_available, reorder_level) VALUES
(1, 25, 5),
(2, 8, 5),
(3, 40, 10),
(4, 15, 5),
(5, 30, 8),
(6, 6, 5),
(7, 60, 15),
(8, 45, 10),
(9, 20, 6),
(10, 18, 6),
(11, 12, 4),
(12, 35, 8),
(13, 10, 4),
(14, 80, 20),
(15, 70, 20),
(16, 50, 15),
(17, 40, 10),
(18, 7, 4),
(19, 55, 10),
(20, 0, 3);

-- Customers
INSERT INTO customer (customer_id, first_name, last_name, email, phone, created_at) VALUES
(1, 'Aarav', 'Sharma', 'aarav.sharma@gmail.com', '9876543210', '2026-06-02 10:15:00'),
(2, 'Diya', 'Patel', 'diya.patel@gmail.com', '9123456780', '2026-06-10 18:40:00'),
(3, 'Vihaan', 'Reddy', 'vihaan.reddy@gmail.com', '9988776655', '2026-06-21 09:05:00'),
(4, 'Ananya', 'Iyer', 'ananya.iyer@gmail.com', '9001234567', '2026-07-01 14:20:00'),
(5, 'Rohan', 'Gupta', 'rohan.gupta@gmail.com', '8899001122', '2026-07-08 20:10:00'),
(6, 'Ishita', 'Nair', 'ishita.nair@gmail.com', '7766554433', '2026-07-15 11:45:00'),
(7, 'Kabir', 'Singh', 'kabir.singh@gmail.com', '9345678901', '2026-07-22 16:30:00'),
(8, 'Meera', 'Joshi', 'meera.joshi@gmail.com', '8123456789', '2026-08-01 08:55:00'),
(9, 'Arjun', 'Verma', 'arjun.verma@gmail.com', '9654321098', '2026-08-09 19:25:00'),
(10, 'Sneha', 'Kulkarni', 'sneha.kulkarni@gmail.com', '7012345678', '2026-08-18 12:00:00');

-- Delivery addresses
INSERT INTO address (address_id, customer_id, address_line, city, state, pincode, is_default) VALUES
(1, 1, 'Flat 302, Lake View Apartments, Madhapur', 'Hyderabad', 'Telangana', '500081', TRUE),
(2, 1, 'Plot 14, Road No. 3, Banjara Hills', 'Hyderabad', 'Telangana', '500034', FALSE),
(3, 2, '21 MG Road, Indiranagar', 'Bengaluru', 'Karnataka', '560038', TRUE),
(4, 3, 'H.No 8-2-120, Kukatpally', 'Hyderabad', 'Telangana', '500072', TRUE),
(5, 4, '12 TTK Road, Alwarpet', 'Chennai', 'Tamil Nadu', '600018', TRUE),
(6, 5, 'B-45, Sector 62', 'Noida', 'Uttar Pradesh', '201309', TRUE),
(7, 6, 'Kaloor Junction, Near Stadium', 'Kochi', 'Kerala', '682017', TRUE),
(8, 7, 'House 77, Sector 17', 'Chandigarh', 'Chandigarh', '160017', TRUE),
(9, 8, 'Flat 5B, Koregaon Park', 'Pune', 'Maharashtra', '411001', TRUE),
(10, 8, 'Office 410, Hinjewadi Phase 1', 'Pune', 'Maharashtra', '411057', FALSE),
(11, 9, '23 Civil Lines', 'Jaipur', 'Rajasthan', '302006', TRUE),
(12, 10, 'Shivaji Nagar, FC Road', 'Pune', 'Maharashtra', '411005', TRUE);

-- =====================================================================
-- Orders. Each order is inserted as 'Placed', then its items, payment and
-- shipment; status changes are applied afterwards with UPDATEs so that
-- the triggers run exactly as they would in the application.
-- =====================================================================

-- Order 1: customer 1
INSERT INTO orders (order_id, order_number, customer_id, address_id, order_date, order_status) VALUES (1, 'ORD-000001', 1, 1, '2026-08-05 11:20:00', 'Placed');
INSERT INTO order_item (order_item_id, order_id, product_id, quantity, unit_price) VALUES (1, 1, 1, 1, 18999.00), (2, 1, 3, 1, 1499.00);
INSERT INTO payment (order_id, amount, payment_method, payment_status, transaction_ref, paid_at) VALUES (1, 20498.00, 'UPI', 'Success', 'TXN-000001-001EEF', '2026-08-05 11:20:00');
UPDATE orders SET order_status = 'Confirmed' WHERE order_id = 1;
INSERT INTO shipment (order_id, courier_name, tracking_number, shipped_date, expected_delivery, shipment_status) VALUES (1, 'Delhivery', 'DE000104729', '2026-08-06', '2026-08-10', 'Shipped');
UPDATE shipment SET shipment_status = 'Delivered', delivered_date = '2026-08-09' WHERE order_id = 1;   -- trigger sets order to Delivered

-- Order 2: customer 2
INSERT INTO orders (order_id, order_number, customer_id, address_id, order_date, order_status) VALUES (2, 'ORD-000002', 2, 3, '2026-08-12 15:05:00', 'Placed');
INSERT INTO order_item (order_item_id, order_id, product_id, quantity, unit_price) VALUES (3, 2, 7, 2, 899.00), (4, 2, 8, 1, 1499.00);
INSERT INTO payment (order_id, amount, payment_method, payment_status, transaction_ref, paid_at) VALUES (2, 3297.00, 'Card', 'Success', 'TXN-000002-003DDE', '2026-08-12 15:05:00');
UPDATE orders SET order_status = 'Confirmed' WHERE order_id = 2;
INSERT INTO shipment (order_id, courier_name, tracking_number, shipped_date, expected_delivery, shipment_status) VALUES (2, 'Blue Dart', 'BL000209458', '2026-08-13', '2026-08-17', 'Shipped');
UPDATE shipment SET shipment_status = 'Delivered', delivered_date = '2026-08-16' WHERE order_id = 2;   -- trigger sets order to Delivered

-- Order 3: customer 3
INSERT INTO orders (order_id, order_number, customer_id, address_id, order_date, order_status) VALUES (3, 'ORD-000003', 3, 4, '2026-08-20 09:40:00', 'Placed');
INSERT INTO order_item (order_item_id, order_id, product_id, quantity, unit_price) VALUES (5, 3, 14, 2, 299.00), (6, 3, 15, 1, 499.00);
INSERT INTO payment (order_id, amount, payment_method, payment_status, transaction_ref, paid_at) VALUES (3, 1097.00, 'UPI', 'Success', 'TXN-000003-005CCD', '2026-08-20 09:40:00');
UPDATE orders SET order_status = 'Confirmed' WHERE order_id = 3;
INSERT INTO shipment (order_id, courier_name, tracking_number, shipped_date, expected_delivery, shipment_status) VALUES (3, 'Ekart', 'EK000314187', '2026-08-21', '2026-08-25', 'Shipped');
UPDATE shipment SET shipment_status = 'Delivered', delivered_date = '2026-08-24' WHERE order_id = 3;   -- trigger sets order to Delivered

-- Order 4: customer 4
INSERT INTO orders (order_id, order_number, customer_id, address_id, order_date, order_status) VALUES (4, 'ORD-000004', 4, 5, '2026-08-28 19:15:00', 'Placed');
INSERT INTO order_item (order_item_id, order_id, product_id, quantity, unit_price) VALUES (7, 4, 11, 1, 3299.00);
INSERT INTO payment (order_id, amount, payment_method, payment_status, transaction_ref, paid_at) VALUES (4, 3299.00, 'NetBanking', 'Success', 'TXN-000004-007BBC', '2026-08-28 19:15:00');
UPDATE orders SET order_status = 'Confirmed' WHERE order_id = 4;
INSERT INTO shipment (order_id, courier_name, tracking_number, shipped_date, expected_delivery, shipment_status) VALUES (4, 'Delhivery', 'DE000418916', '2026-08-29', '2026-09-02', 'Shipped');
UPDATE shipment SET shipment_status = 'Delivered', delivered_date = '2026-09-02' WHERE order_id = 4;   -- trigger sets order to Delivered

-- Order 5: customer 5
INSERT INTO orders (order_id, order_number, customer_id, address_id, order_date, order_status) VALUES (5, 'ORD-000005', 5, 6, '2026-09-03 13:30:00', 'Placed');
INSERT INTO order_item (order_item_id, order_id, product_id, quantity, unit_price) VALUES (8, 5, 17, 1, 699.00), (9, 5, 19, 2, 349.00);
INSERT INTO payment (order_id, amount, payment_method, payment_status, transaction_ref, paid_at) VALUES (5, 1397.00, 'COD', 'Success', 'TXN-000005-009AAB', '2026-09-03 13:30:00');
UPDATE orders SET order_status = 'Confirmed' WHERE order_id = 5;
INSERT INTO shipment (order_id, courier_name, tracking_number, shipped_date, expected_delivery, shipment_status) VALUES (5, 'Ekart', 'EK000523645', '2026-09-04', '2026-09-08', 'Shipped');
UPDATE shipment SET shipment_status = 'Delivered', delivered_date = '2026-09-07' WHERE order_id = 5;   -- trigger sets order to Delivered

-- Order 6: customer 6
INSERT INTO orders (order_id, order_number, customer_id, address_id, order_date, order_status) VALUES (6, 'ORD-000006', 6, 7, '2026-09-10 10:10:00', 'Placed');
INSERT INTO order_item (order_item_id, order_id, product_id, quantity, unit_price) VALUES (10, 6, 4, 1, 4999.00);
INSERT INTO payment (order_id, amount, payment_method, payment_status, transaction_ref, paid_at) VALUES (6, 4999.00, 'UPI', 'Success', 'TXN-000006-00B99A', '2026-09-10 10:10:00');
UPDATE orders SET order_status = 'Confirmed' WHERE order_id = 6;
INSERT INTO shipment (order_id, courier_name, tracking_number, shipped_date, expected_delivery, shipment_status) VALUES (6, 'Blue Dart', 'BL000628374', '2026-09-11', '2026-09-15', 'Shipped');
UPDATE shipment SET shipment_status = 'Delivered', delivered_date = '2026-09-14' WHERE order_id = 6;   -- trigger sets order to Delivered

-- Order 7: customer 7
INSERT INTO orders (order_id, order_number, customer_id, address_id, order_date, order_status) VALUES (7, 'ORD-000007', 7, 8, '2026-09-18 17:45:00', 'Placed');
INSERT INTO order_item (order_item_id, order_id, product_id, quantity, unit_price) VALUES (11, 7, 9, 1, 2499.00), (12, 7, 10, 1, 1999.00);
INSERT INTO payment (order_id, amount, payment_method, payment_status, transaction_ref, paid_at) VALUES (7, 4498.00, 'Card', 'Success', 'TXN-000007-00D889', '2026-09-18 17:45:00');
UPDATE orders SET order_status = 'Confirmed' WHERE order_id = 7;
INSERT INTO shipment (order_id, courier_name, tracking_number, shipped_date, expected_delivery, shipment_status) VALUES (7, 'Delhivery', 'DE000733103', '2026-09-19', '2026-09-23', 'Shipped');
UPDATE shipment SET shipment_status = 'Delivered', delivered_date = '2026-09-23' WHERE order_id = 7;   -- trigger sets order to Delivered

-- Order 8: customer 8
INSERT INTO orders (order_id, order_number, customer_id, address_id, order_date, order_status) VALUES (8, 'ORD-000008', 8, 9, '2026-09-25 12:25:00', 'Placed');
INSERT INTO order_item (order_item_id, order_id, product_id, quantity, unit_price) VALUES (13, 8, 2, 1, 16499.00), (14, 8, 5, 1, 1295.00);
INSERT INTO payment (order_id, amount, payment_method, payment_status, transaction_ref, paid_at) VALUES (8, 17794.00, 'UPI', 'Success', 'TXN-000008-00F778', '2026-09-25 12:25:00');
UPDATE orders SET order_status = 'Confirmed' WHERE order_id = 8;
INSERT INTO shipment (order_id, courier_name, tracking_number, shipped_date, expected_delivery, shipment_status) VALUES (8, 'Ekart', 'EK000837832', '2026-09-26', '2026-09-30', 'Shipped');
UPDATE shipment SET shipment_status = 'Delivered', delivered_date = '2026-09-29' WHERE order_id = 8;   -- trigger sets order to Delivered

-- Order 9: customer 1
INSERT INTO orders (order_id, order_number, customer_id, address_id, order_date, order_status) VALUES (9, 'ORD-000009', 1, 2, '2026-10-01 09:00:00', 'Placed');
INSERT INTO order_item (order_item_id, order_id, product_id, quantity, unit_price) VALUES (15, 9, 12, 2, 799.00), (16, 9, 13, 1, 1899.00);
INSERT INTO payment (order_id, amount, payment_method, payment_status, transaction_ref, paid_at) VALUES (9, 3497.00, 'Card', 'Success', 'TXN-000009-011667', '2026-10-01 09:00:00');
UPDATE orders SET order_status = 'Confirmed' WHERE order_id = 9;
INSERT INTO shipment (order_id, courier_name, tracking_number, shipped_date, expected_delivery, shipment_status) VALUES (9, 'Blue Dart', 'BL000942561', '2026-10-02', '2026-10-06', 'Shipped');
UPDATE shipment SET shipment_status = 'Delivered', delivered_date = '2026-10-05' WHERE order_id = 9;   -- trigger sets order to Delivered

-- Order 10: customer 9
INSERT INTO orders (order_id, order_number, customer_id, address_id, order_date, order_status) VALUES (10, 'ORD-000010', 9, 11, '2026-10-02 20:30:00', 'Placed');
INSERT INTO order_item (order_item_id, order_id, product_id, quantity, unit_price) VALUES (17, 10, 18, 1, 2799.00), (18, 10, 17, 1, 699.00);
INSERT INTO payment (order_id, amount, payment_method, payment_status, transaction_ref, paid_at) VALUES (10, 3498.00, 'UPI', 'Success', 'TXN-000010-013556', '2026-10-02 20:30:00');
UPDATE orders SET order_status = 'Confirmed' WHERE order_id = 10;
INSERT INTO shipment (order_id, courier_name, tracking_number, shipped_date, expected_delivery, shipment_status) VALUES (10, 'Delhivery', 'DE001047290', '2026-10-03', '2026-10-07', 'Shipped');
UPDATE shipment SET shipment_status = 'Delivered', delivered_date = '2026-10-06' WHERE order_id = 10;   -- trigger sets order to Delivered

-- Order 11: customer 10
INSERT INTO orders (order_id, order_number, customer_id, address_id, order_date, order_status) VALUES (11, 'ORD-000011', 10, 12, '2026-10-03 14:10:00', 'Placed');
INSERT INTO order_item (order_item_id, order_id, product_id, quantity, unit_price) VALUES (19, 11, 8, 2, 1499.00), (20, 11, 7, 1, 899.00);
INSERT INTO payment (order_id, amount, payment_method, payment_status, transaction_ref, paid_at) VALUES (11, 3897.00, 'UPI', 'Success', 'TXN-000011-015445', '2026-10-03 14:10:00');
UPDATE orders SET order_status = 'Confirmed' WHERE order_id = 11;
INSERT INTO shipment (order_id, courier_name, tracking_number, shipped_date, expected_delivery, shipment_status) VALUES (11, 'Ekart', 'EK001152019', '2026-10-04', '2026-10-08', 'Shipped');
UPDATE shipment SET shipment_status = 'Delivered', delivered_date = '2026-10-07' WHERE order_id = 11;   -- trigger sets order to Delivered

-- Order 12: customer 2
INSERT INTO orders (order_id, order_number, customer_id, address_id, order_date, order_status) VALUES (12, 'ORD-000012', 2, 3, '2026-10-05 16:50:00', 'Placed');
INSERT INTO order_item (order_item_id, order_id, product_id, quantity, unit_price) VALUES (21, 12, 16, 3, 349.00), (22, 12, 14, 1, 299.00);
INSERT INTO payment (order_id, amount, payment_method, payment_status, transaction_ref, paid_at) VALUES (12, 1346.00, 'NetBanking', 'Success', 'TXN-000012-017334', '2026-10-05 16:50:00');
UPDATE orders SET order_status = 'Confirmed' WHERE order_id = 12;
INSERT INTO shipment (order_id, courier_name, tracking_number, shipped_date, expected_delivery, shipment_status) VALUES (12, 'Blue Dart', 'BL001256748', '2026-10-06', '2026-10-10', 'Shipped');
UPDATE shipment SET shipment_status = 'Delivered', delivered_date = '2026-10-08' WHERE order_id = 12;   -- trigger sets order to Delivered

-- Order 13: customer 3
INSERT INTO orders (order_id, order_number, customer_id, address_id, order_date, order_status) VALUES (13, 'ORD-000013', 3, 4, '2026-10-07 11:35:00', 'Placed');
INSERT INTO order_item (order_item_id, order_id, product_id, quantity, unit_price) VALUES (23, 13, 3, 2, 1499.00);
INSERT INTO payment (order_id, amount, payment_method, payment_status, transaction_ref, paid_at) VALUES (13, 2998.00, 'UPI', 'Success', 'TXN-000013-019223', '2026-10-07 11:35:00');
UPDATE orders SET order_status = 'Confirmed' WHERE order_id = 13;
INSERT INTO shipment (order_id, courier_name, tracking_number, shipped_date, expected_delivery, shipment_status) VALUES (13, 'Delhivery', 'DE001361477', '2026-10-08', '2026-10-12', 'Shipped');
UPDATE shipment SET shipment_status = 'In Transit' WHERE order_id = 13;   -- trigger sets order to Shipped

-- Order 14: customer 5
INSERT INTO orders (order_id, order_number, customer_id, address_id, order_date, order_status) VALUES (14, 'ORD-000014', 5, 6, '2026-10-08 18:05:00', 'Placed');
INSERT INTO order_item (order_item_id, order_id, product_id, quantity, unit_price) VALUES (24, 14, 6, 2, 999.00), (25, 14, 5, 1, 1295.00);
INSERT INTO payment (order_id, amount, payment_method, payment_status, transaction_ref, paid_at) VALUES (14, 3293.00, 'Card', 'Success', 'TXN-000014-01B112', '2026-10-08 18:05:00');
UPDATE orders SET order_status = 'Confirmed' WHERE order_id = 14;
INSERT INTO shipment (order_id, courier_name, tracking_number, shipped_date, expected_delivery, shipment_status) VALUES (14, 'Ekart', 'EK001466206', '2026-10-09', '2026-10-13', 'Shipped');
UPDATE shipment SET shipment_status = 'In Transit' WHERE order_id = 14;   -- trigger sets order to Shipped

-- Order 15: customer 6
INSERT INTO orders (order_id, order_number, customer_id, address_id, order_date, order_status) VALUES (15, 'ORD-000015', 6, 7, '2026-10-09 10:20:00', 'Placed');
INSERT INTO order_item (order_item_id, order_id, product_id, quantity, unit_price) VALUES (26, 15, 11, 1, 3299.00), (27, 15, 12, 1, 799.00);
INSERT INTO payment (order_id, amount, payment_method, payment_status, transaction_ref, paid_at) VALUES (15, 4098.00, 'COD', 'Pending', 'TXN-000015-01D001', '2026-10-09 10:20:00');
UPDATE orders SET order_status = 'Confirmed' WHERE order_id = 15;

-- Order 16: customer 4
INSERT INTO orders (order_id, order_number, customer_id, address_id, order_date, order_status) VALUES (16, 'ORD-000016', 4, 5, '2026-10-09 21:40:00', 'Placed');
INSERT INTO order_item (order_item_id, order_id, product_id, quantity, unit_price) VALUES (28, 16, 1, 1, 18999.00);
INSERT INTO payment (order_id, amount, payment_method, payment_status, transaction_ref, paid_at) VALUES (16, 18999.00, 'UPI', 'Success', 'TXN-000016-01EEF0', '2026-10-09 21:40:00');
UPDATE orders SET order_status = 'Confirmed' WHERE order_id = 16;

-- Order 17: customer 7
INSERT INTO orders (order_id, order_number, customer_id, address_id, order_date, order_status) VALUES (17, 'ORD-000017', 7, 8, '2026-09-12 08:30:00', 'Placed');
INSERT INTO order_item (order_item_id, order_id, product_id, quantity, unit_price) VALUES (29, 17, 18, 2, 2799.00);
INSERT INTO payment (order_id, amount, payment_method, payment_status, transaction_ref, paid_at) VALUES (17, 5598.00, 'UPI', 'Failed', 'TXN-000017-020DDF', '2026-09-12 08:30:00');
UPDATE orders SET order_status = 'Cancelled' WHERE order_id = 17;   -- trigger puts the stock back

-- Order 18: customer 9
INSERT INTO orders (order_id, order_number, customer_id, address_id, order_date, order_status) VALUES (18, 'ORD-000018', 9, 11, '2026-09-29 13:15:00', 'Placed');
INSERT INTO order_item (order_item_id, order_id, product_id, quantity, unit_price) VALUES (30, 18, 9, 1, 2499.00);
INSERT INTO payment (order_id, amount, payment_method, payment_status, transaction_ref, paid_at) VALUES (18, 2499.00, 'Card', 'Failed', 'TXN-000018-022CCE', '2026-09-29 13:15:00');
UPDATE orders SET order_status = 'Cancelled' WHERE order_id = 18;   -- trigger puts the stock back

-- =====================================================================
-- Returns (inserted as 'Requested'; the trigger checks delivery and the
-- return window), then approved / rejected / received by the admin.
-- =====================================================================
INSERT INTO return_request (return_id, order_item_id, quantity, reason, request_date) VALUES (1, 3, 1, 'Size too small', '2026-08-20');
UPDATE return_request SET return_status = 'Approved', decided_at = '2026-08-21 10:00:00' WHERE return_id = 1;
UPDATE return_request SET return_status = 'Received' WHERE return_id = 1;   -- trigger restocks
INSERT INTO return_request (return_id, order_item_id, quantity, reason, request_date) VALUES (2, 12, 1, 'Colour different from the picture', '2026-09-28');
UPDATE return_request SET return_status = 'Approved', decided_at = '2026-09-29 12:30:00' WHERE return_id = 2;
UPDATE return_request SET return_status = 'Received' WHERE return_id = 2;   -- trigger restocks
INSERT INTO return_request (return_id, order_item_id, quantity, reason, request_date) VALUES (3, 16, 1, 'Non-stick coating peeling off', '2026-10-07');
UPDATE return_request SET return_status = 'Approved', decided_at = '2026-10-08 09:15:00' WHERE return_id = 3;
INSERT INTO return_request (return_id, order_item_id, quantity, reason, request_date) VALUES (4, 19, 1, 'Fit is too loose', '2026-10-09');
INSERT INTO return_request (return_id, order_item_id, quantity, reason, request_date) VALUES (5, 14, 1, 'Changed my mind', '2026-10-05');
UPDATE return_request SET return_status = 'Rejected', decided_at = '2026-10-06 11:00:00' WHERE return_id = 5;
INSERT INTO return_request (return_id, order_item_id, quantity, reason, request_date) VALUES (6, 21, 2, 'Received damaged copies', '2026-10-09');
UPDATE return_request SET return_status = 'Approved', decided_at = '2026-10-10 15:45:00' WHERE return_id = 6;

-- =====================================================================
-- Refunds (trigger checks: approved/received return, successful payment,
-- amount <= returned value and total refunds <= amount paid)
-- =====================================================================
INSERT INTO refund (refund_id, return_id, refund_amount, refund_method, refund_status, initiated_at, processed_at) VALUES (1, 1, 899.00, 'Original Payment', 'Processed', '2026-08-21 11:00:00', '2026-08-23 17:00:00');
INSERT INTO refund (refund_id, return_id, refund_amount, refund_method, refund_status, initiated_at, processed_at) VALUES (2, 2, 1999.00, 'Original Payment', 'Processed', '2026-09-29 13:00:00', '2026-10-01 10:30:00');
INSERT INTO refund (refund_id, return_id, refund_amount, refund_method, refund_status, initiated_at, processed_at) VALUES (3, 3, 1899.00, 'Original Payment', 'Initiated', '2026-10-08 10:00:00', NULL);
INSERT INTO refund (refund_id, return_id, refund_amount, refund_method, refund_status, initiated_at, processed_at) VALUES (4, 6, 698.00, 'Original Payment', 'Processed', '2026-10-10 16:00:00', '2026-10-11 09:00:00');

-- Reviews (trigger allows only customers who received the product)
INSERT INTO review (customer_id, product_id, rating, comment, review_date) VALUES
(1, 1, 5, 'Excellent phone for the price, battery easily lasts a day.', '2026-08-15'),
(1, 3, 4, 'Good bass, ear cushions could be softer.', '2026-08-16'),
(2, 8, 4, 'Good fit and comfortable fabric.', '2026-08-22'),
(3, 14, 5, 'A timeless read, delivered in perfect condition.', '2026-08-28'),
(3, 15, 5, 'Life-changing book. Highly recommended.', '2026-08-30'),
(4, 11, 4, 'Powerful motor, a little noisy.', '2026-09-06'),
(5, 17, 3, 'Decent mat but slightly thin.', '2026-09-10'),
(6, 4, 5, 'Noise cancellation works really well on the metro.', '2026-09-18'),
(7, 9, 4, 'Light and comfortable for daily runs.', '2026-09-27'),
(8, 2, 4, 'Smooth performance, camera is average.', '2026-10-02'),
(9, 18, 5, 'Solid build, easy to adjust weights.', '2026-10-08'),
(10, 7, 4, 'Nice shirt, colour as shown.', '2026-10-09'),
(2, 16, 2, 'Two copies arrived damaged; returned them.', '2026-10-09');

-- Shopping carts (one per customer) and current cart items for the checkout demo
INSERT INTO cart (cart_id, customer_id) VALUES (1, 1), (2, 2), (3, 3), (4, 4), (5, 5), (6, 6), (7, 7), (8, 8), (9, 9), (10, 10);
INSERT INTO cart_item (cart_id, product_id, quantity) VALUES (1, 5, 1), (1, 19, 2), (3, 15, 1), (3, 16, 1), (4, 12, 1), (7, 9, 1), (8, 3, 1), (8, 14, 2), (10, 17, 1);

-- Quick check: row counts per table
SELECT (SELECT COUNT(*) FROM seller) AS seller,
       (SELECT COUNT(*) FROM category) AS category,
       (SELECT COUNT(*) FROM product) AS product,
       (SELECT COUNT(*) FROM inventory) AS inventory,
       (SELECT COUNT(*) FROM customer) AS customer,
       (SELECT COUNT(*) FROM address) AS address,
       (SELECT COUNT(*) FROM cart) AS cart,
       (SELECT COUNT(*) FROM cart_item) AS cart_item,
       (SELECT COUNT(*) FROM orders) AS orders,
       (SELECT COUNT(*) FROM order_item) AS order_item,
       (SELECT COUNT(*) FROM payment) AS payment,
       (SELECT COUNT(*) FROM shipment) AS shipment,
       (SELECT COUNT(*) FROM return_request) AS return_request,
       (SELECT COUNT(*) FROM refund) AS refund,
       (SELECT COUNT(*) FROM review) AS review;


-- ===== from 04_views.sql =====
-- =====================================================================
-- File 04: Report views
--   v_order_summary        one row per order with totals (used by the app)
--   1 v_order_status_report   order status
--   2 v_seller_performance    seller performance
--   3 v_stock_status          stock
--   4 v_return_report         returns
--   5 v_refund_report         refunds
--   6 v_product_ratings       product ratings
--   7 v_monthly_revenue       revenue
-- =====================================================================

-- Helper: one row per order with its total, payment and shipment state
CREATE OR REPLACE VIEW v_order_summary AS
SELECT o.order_id,
       o.order_number,
       CONCAT(c.first_name, ' ', c.last_name)   AS customer_name,
       DATE(o.order_date)                       AS order_date,
       o.order_status,
       COUNT(oi.order_item_id)                  AS item_lines,
       SUM(oi.quantity)                         AS units,
       SUM(oi.quantity * oi.unit_price)         AS order_total,
       p.payment_method,
       p.payment_status,
       COALESCE(s.shipment_status, 'Not shipped') AS shipment_status
  FROM orders o
  JOIN customer c         ON c.customer_id = o.customer_id
  JOIN order_item oi      ON oi.order_id   = o.order_id
  LEFT JOIN payment p     ON p.order_id    = o.order_id
  LEFT JOIN shipment s    ON s.order_id    = o.order_id
 GROUP BY o.order_id, o.order_number, c.first_name, c.last_name, o.order_date, o.order_status,
          p.payment_method, p.payment_status, s.shipment_status;

-- 1. ORDER STATUS: how many orders are in each state and their value
CREATE OR REPLACE VIEW v_order_status_report AS
SELECT order_status,
       COUNT(*)          AS orders,
       SUM(order_total)  AS order_value
  FROM v_order_summary
 GROUP BY order_status;

-- 2. SELLER PERFORMANCE: products, units sold, sales, returns, refunds, rating
CREATE OR REPLACE VIEW v_seller_performance AS
SELECT s.seller_id,
       s.store_name,
       (SELECT COUNT(*) FROM product p WHERE p.seller_id = s.seller_id)                    AS products_listed,
       COALESCE(sales.units_sold, 0)                                                       AS units_sold,
       COALESCE(sales.gross_sales, 0)                                                      AS gross_sales,
       COALESCE(ret.units_returned, 0)                                                     AS units_returned,
       COALESCE(ref.refunded, 0)                                                           AS refunded_amount,
       COALESCE(sales.gross_sales, 0) - COALESCE(ref.refunded, 0)                          AS net_sales,
       (SELECT ROUND(AVG(rv.rating), 2) FROM review rv JOIN product p ON p.product_id = rv.product_id
         WHERE p.seller_id = s.seller_id)                                                  AS avg_rating
  FROM seller s
  LEFT JOIN (SELECT p.seller_id, SUM(oi.quantity) AS units_sold, SUM(oi.quantity * oi.unit_price) AS gross_sales
               FROM order_item oi
               JOIN orders o  ON o.order_id = oi.order_id AND o.order_status <> 'Cancelled'
               JOIN product p ON p.product_id = oi.product_id
              GROUP BY p.seller_id) sales ON sales.seller_id = s.seller_id
  LEFT JOIN (SELECT p.seller_id, SUM(r.quantity) AS units_returned
               FROM return_request r
               JOIN order_item oi ON oi.order_item_id = r.order_item_id
               JOIN product p     ON p.product_id = oi.product_id
              WHERE r.return_status <> 'Rejected'
              GROUP BY p.seller_id) ret ON ret.seller_id = s.seller_id
  LEFT JOIN (SELECT p.seller_id, SUM(f.refund_amount) AS refunded
               FROM refund f
               JOIN return_request r ON r.return_id = f.return_id
               JOIN order_item oi    ON oi.order_item_id = r.order_item_id
               JOIN product p        ON p.product_id = oi.product_id
              WHERE f.refund_status = 'Processed'
              GROUP BY p.seller_id) ref ON ref.seller_id = s.seller_id;

-- 3. STOCK: current stock with a status flag
CREATE OR REPLACE VIEW v_stock_status AS
SELECT p.product_code,
       p.product_name,
       s.store_name,
       i.quantity_available,
       i.reorder_level,
       CASE WHEN p.is_active = FALSE               THEN 'Discontinued'
            WHEN i.quantity_available = 0          THEN 'Out of stock'
            WHEN i.quantity_available <= i.reorder_level THEN 'Low stock'
            ELSE 'In stock' END                    AS stock_status
  FROM product p
  JOIN inventory i ON i.product_id = p.product_id
  JOIN seller s    ON s.seller_id  = p.seller_id;

-- 4. RETURNS: every return with customer, product and days after delivery
CREATE OR REPLACE VIEW v_return_report AS
SELECT r.return_id,
       o.order_number,
       CONCAT(c.first_name, ' ', c.last_name)        AS customer_name,
       p.product_name,
       r.quantity,
       r.reason,
       sh.delivered_date,
       r.request_date,
       DATEDIFF(r.request_date, sh.delivered_date)   AS days_after_delivery,
       p.return_window_days,
       r.return_status
  FROM return_request r
  JOIN order_item oi ON oi.order_item_id = r.order_item_id
  JOIN orders o      ON o.order_id = oi.order_id
  JOIN customer c    ON c.customer_id = o.customer_id
  JOIN product p     ON p.product_id = oi.product_id
  JOIN shipment sh   ON sh.order_id = o.order_id;

-- 5. REFUNDS: each refund against the amount paid for the order
CREATE OR REPLACE VIEW v_refund_report AS
SELECT f.refund_id,
       o.order_number,
       p.product_name,
       f.refund_amount,
       pay.amount                                     AS order_paid,
       pay.payment_method,
       f.refund_status,
       DATE(f.initiated_at)                           AS initiated_on,
       DATE(f.processed_at)                           AS processed_on,
       DATEDIFF(f.processed_at, f.initiated_at)       AS days_to_process
  FROM refund f
  JOIN return_request r ON r.return_id = f.return_id
  JOIN order_item oi    ON oi.order_item_id = r.order_item_id
  JOIN orders o         ON o.order_id = oi.order_id
  JOIN product p        ON p.product_id = oi.product_id
  JOIN payment pay      ON pay.order_id = o.order_id;

-- 6. PRODUCT RATINGS
CREATE OR REPLACE VIEW v_product_ratings AS
SELECT p.product_code,
       p.product_name,
       COUNT(rv.review_id)          AS reviews,
       ROUND(AVG(rv.rating), 2)     AS avg_rating,
       MIN(rv.rating)               AS lowest,
       MAX(rv.rating)               AS highest
  FROM product p
  LEFT JOIN review rv ON rv.product_id = p.product_id
 GROUP BY p.product_id, p.product_code, p.product_name;

-- 7. REVENUE by month: successful payments minus processed refunds
CREATE OR REPLACE VIEW v_monthly_revenue AS
SELECT m.month,
       COALESCE(sales.orders, 0)                               AS paid_orders,
       COALESCE(sales.gross_revenue, 0)                        AS gross_revenue,
       COALESCE(rf.refunds, 0)                                 AS refunds,
       COALESCE(sales.gross_revenue, 0) - COALESCE(rf.refunds, 0) AS net_revenue
  FROM (SELECT DATE_FORMAT(paid_at, '%Y-%m') AS month FROM payment WHERE payment_status = 'Success'
        UNION
        SELECT DATE_FORMAT(processed_at, '%Y-%m') FROM refund WHERE refund_status = 'Processed') m
  LEFT JOIN (SELECT DATE_FORMAT(paid_at, '%Y-%m') AS month, COUNT(*) AS orders, SUM(amount) AS gross_revenue
               FROM payment WHERE payment_status = 'Success'
              GROUP BY DATE_FORMAT(paid_at, '%Y-%m')) sales ON sales.month = m.month
  LEFT JOIN (SELECT DATE_FORMAT(processed_at, '%Y-%m') AS month, SUM(refund_amount) AS refunds
               FROM refund WHERE refund_status = 'Processed'
              GROUP BY DATE_FORMAT(processed_at, '%Y-%m')) rf ON rf.month = m.month;

-- Show every report
SELECT * FROM v_order_status_report;
SELECT * FROM v_seller_performance;
SELECT * FROM v_stock_status ORDER BY FIELD(stock_status,'Out of stock','Low stock','Discontinued','In stock'), quantity_available;
SELECT * FROM v_return_report ORDER BY return_id;
SELECT * FROM v_refund_report ORDER BY refund_id;
SELECT * FROM v_product_ratings ORDER BY avg_rating DESC, reviews DESC;
SELECT * FROM v_monthly_revenue ORDER BY month;

