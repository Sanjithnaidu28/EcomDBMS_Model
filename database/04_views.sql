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
USE ecommerce_dbms;

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
