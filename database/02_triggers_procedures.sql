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
USE ecommerce_dbms;

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
