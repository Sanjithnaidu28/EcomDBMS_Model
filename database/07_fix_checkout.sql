-- =====================================================================
-- File 07: Fix for checkout error 1442 (run once, whole file, ⚡ button)
-- Recreates the stock trigger and the checkout procedure so that the
-- INSERT in sp_place_order no longer reads the product table that the
-- trigger locks. Your data is not changed.
-- =====================================================================
USE ecommerce_dbms;

DROP TRIGGER IF EXISTS trg_orderitem_before_insert;
DROP PROCEDURE IF EXISTS sp_place_order;

DELIMITER $$

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

SELECT 'Checkout fix installed' AS status;
