-- =====================================================================
-- File 03: Realistic sample data (Indian e-commerce context)
-- Generated so that every row satisfies the triggers in file 02.
-- Inserts follow the real workflow: order -> items -> payment ->
-- shipment -> status updates -> returns -> refunds -> reviews.
-- =====================================================================
USE ecommerce_dbms;

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
