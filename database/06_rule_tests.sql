-- =====================================================================
-- File 06: Business-rule tests (proof that the database rejects bad data)
-- Run ONE test at a time: put the cursor on the statement and press
-- Cmd+Enter. Negative tests are SUPPOSED to fail - screenshot the red
-- error in the Output panel; that error is the evidence.
-- Positive tests are wrapped in a transaction and rolled back, so the
-- sample data stays the same for the reports.
-- =====================================================================
USE ecommerce_dbms;

-- ---------------------------------------------------------------------
-- RULE 1: ORDER QUANTITY WITHIN STOCK
-- ---------------------------------------------------------------------
-- T1 (negative) Add 100 phones to order ORD-000016 when only 7 are in stock
-- Expected: Error 1644 'Order quantity exceeds available stock.'
INSERT INTO order_item (order_id, product_id, quantity, unit_price) VALUES (16, 2, 100, 16499.00);

-- T2 (negative) Stock can never go negative even with a direct update
-- Expected: Error 3819 Check constraint 'chk_inventory_qty' is violated.
UPDATE inventory SET quantity_available = -1 WHERE product_id = 2;

-- T3 (negative) Checkout with more dumbbells in the cart than in stock:
--               the whole transaction rolls back
START TRANSACTION;
INSERT INTO cart_item (cart_id, product_id, quantity) VALUES (5, 18, 50);
COMMIT;
CALL sp_place_order(5, 6, 'UPI', @new_order);      -- Expected: Error 1644 'Order quantity exceeds available stock.'
SELECT quantity_available FROM inventory WHERE product_id = 18;   -- still 6: nothing was taken out
DELETE FROM cart_item WHERE cart_id = 5 AND product_id = 18;      -- clean up

-- ---------------------------------------------------------------------
-- RULE 2: AT LEAST ONE ITEM PER ORDER
-- ---------------------------------------------------------------------
-- T4 (negative) Checkout with an empty cart (customer 2 has no cart items)
-- Expected: Error 1644 'Cart is empty: an order needs at least one item.'
CALL sp_place_order(2, 3, 'UPI', @new_order);

-- T5 (negative) Remove the only item of order ORD-000016
-- Expected: Error 1644 'An order must contain at least one item. Cancel the order instead.'
DELETE FROM order_item WHERE order_id = 16;

-- T6 (negative) Order item with quantity 0
-- Expected: Error 3819 Check constraint 'chk_orderitem_qty' is violated.
INSERT INTO order_item (order_id, product_id, quantity, unit_price) VALUES (16, 3, 0, 1499.00);

-- ---------------------------------------------------------------------
-- RULE 3: VALID RETURN PERIOD
-- ---------------------------------------------------------------------
-- T7 (negative) Return the phone from ORD-000001: delivered 2026-08-09, 7-day window
-- Expected: Error 1644 'Return not allowed: the return period for this product has ended.'
INSERT INTO return_request (order_item_id, quantity, reason, request_date) VALUES (1, 1, 'Not satisfied', '2026-10-11');

-- T8 (negative) Return an item from ORD-000013, which is still in transit
-- Expected: Error 1644 'Return not allowed: the order has not been delivered yet.'
INSERT INTO return_request (order_item_id, quantity, reason, request_date)
SELECT order_item_id, 1, 'Ordered by mistake', '2026-10-11' FROM order_item WHERE order_id = 13;

-- T9 (negative) Return more units than were bought (ORD-000012 has 1 copy of The Alchemist)
-- Expected: Error 1644 'Return quantity exceeds the quantity purchased.'
INSERT INTO return_request (order_item_id, quantity, reason, request_date)
SELECT order_item_id, 5, 'Bulk return', '2026-10-11' FROM order_item WHERE order_id = 12 AND product_id = 14;

-- ---------------------------------------------------------------------
-- RULE 4: REFUND WITHIN PAID AMOUNT
-- ---------------------------------------------------------------------
-- T10 (negative) Refund a return that is only 'Requested' (return 4)
-- Expected: Error 1644 'Refund allowed only for an approved or received return.'
INSERT INTO refund (return_id, refund_amount) VALUES (4, 1499.00);

-- T11 (negative) Approve return 4 (1 pair of jeans, Rs 1499) and try to refund Rs 5000
START TRANSACTION;
UPDATE return_request SET return_status = 'Approved', decided_at = NOW() WHERE return_id = 4;
INSERT INTO refund (return_id, refund_amount) VALUES (4, 5000.00);   -- Expected: Error 1644 'Refund exceeds the value of the returned items.'
ROLLBACK;

-- ---------------------------------------------------------------------
-- RULE 5: UNIQUE PRODUCT CODES
-- ---------------------------------------------------------------------
-- T12 (negative) Add a product with an existing code
-- Expected: Error 1062 Duplicate entry 'TN-MOB-001' for key 'product.uq_product_code'
INSERT INTO product (product_code, seller_id, category_id, product_name, unit_price)
VALUES ('TN-MOB-001', 1, 6, 'Duplicate Phone', 9999.00);

-- ---------------------------------------------------------------------
-- OTHER INTEGRITY CHECKS
-- ---------------------------------------------------------------------
-- T13 (negative) Rating outside 1-5. Expected: Error 3819 chk_review_rating
INSERT INTO review (customer_id, product_id, rating) VALUES (1, 12, 6);

-- T14 (negative) Review by a customer who never received the product
-- Expected: Error 1644 'Only customers who received this product can review it.'
INSERT INTO review (customer_id, product_id, rating, comment) VALUES (10, 1, 5, 'Great!');

-- T15 (negative) Order for a customer that does not exist. Expected: Error 1452 foreign key fails
INSERT INTO orders (order_number, customer_id, address_id) VALUES ('ORD-999999', 999, 1);

-- T16 (negative) Invalid phone number. Expected: Error 3819 chk_customer_phone
INSERT INTO customer (first_name, last_name, email, phone) VALUES ('Test', 'User', 'test@gmail.com', '12345');

-- =====================================================================
-- POSITIVE TESTS (each one rolls back at the end)
-- =====================================================================
-- T17 (positive) Checkout = one transaction. Customer 1 has a mouse and 2 skipping ropes in the cart.
START TRANSACTION;
SELECT product_id, quantity_available FROM inventory WHERE product_id IN (5, 19);   -- before: 28 and 53
CALL sp_place_order(1, 1, 'UPI', @new_order);
SELECT @new_order AS new_order_id;
SELECT * FROM v_order_summary WHERE order_id = @new_order;                          -- Confirmed, Rs 1993.00, UPI Success
SELECT product_id, quantity_available FROM inventory WHERE product_id IN (5, 19);   -- after: 27 and 51
SELECT COUNT(*) AS items_left_in_cart FROM cart_item WHERE cart_id = 1;             -- 0
ROLLBACK;

-- T18 (positive) Cancel an order: its stock goes back automatically
START TRANSACTION;
SELECT quantity_available FROM inventory WHERE product_id = 1;   -- before: 23
UPDATE orders SET order_status = 'Cancelled' WHERE order_id = 16;
SELECT quantity_available FROM inventory WHERE product_id = 1;   -- after: 24
ROLLBACK;

-- T19 (positive) A valid return inside the window, then approval and refund
START TRANSACTION;
INSERT INTO return_request (order_item_id, quantity, reason, request_date)
SELECT order_item_id, 1, 'Cover torn', '2026-10-11' FROM order_item WHERE order_id = 12 AND product_id = 14;
SET @ret = LAST_INSERT_ID();
UPDATE return_request SET return_status = 'Approved', decided_at = NOW() WHERE return_id = @ret;
INSERT INTO refund (return_id, refund_amount) VALUES (@ret, 299.00);
SELECT * FROM v_refund_report WHERE refund_id = LAST_INSERT_ID();
ROLLBACK;

-- T20 (positive) Shipment delivered -> order becomes Delivered automatically
START TRANSACTION;
UPDATE shipment SET shipment_status = 'Delivered', delivered_date = '2026-10-11' WHERE order_id = 13;
SELECT order_number, order_status FROM orders WHERE order_id = 13;   -- Delivered
ROLLBACK;
