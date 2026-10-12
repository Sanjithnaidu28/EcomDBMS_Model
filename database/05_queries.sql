-- =====================================================================
-- File 05: SQL queries - retrieval, joins, aggregation, subqueries
-- Run one query at a time in Workbench: put the cursor inside it and
-- press Ctrl+Enter (Cmd+Enter on Mac) to see its result grid.
-- =====================================================================
USE ecommerce_dbms;

-- Q1. Retrieval with search: active products whose name contains 'shoe' or 'sneaker'
SELECT product_code, product_name, unit_price
  FROM product
 WHERE is_active = TRUE
   AND (product_name LIKE '%shoe%' OR product_name LIKE '%sneaker%')
 ORDER BY unit_price;

-- Q2. INNER JOIN (5 tables): full details of every item in order ORD-000001
SELECT o.order_number, CONCAT(c.first_name, ' ', c.last_name) AS customer,
       p.product_name, s.store_name AS seller, oi.quantity, oi.unit_price,
       oi.quantity * oi.unit_price AS line_total
  FROM orders o
  JOIN customer c    ON c.customer_id = o.customer_id
  JOIN order_item oi ON oi.order_id   = o.order_id
  JOIN product p     ON p.product_id  = oi.product_id
  JOIN seller s      ON s.seller_id   = p.seller_id
 WHERE o.order_number = 'ORD-000001';

-- Q3. Shipment tracking: where is each order that has not been delivered yet?
SELECT o.order_number, o.order_status, s.courier_name, s.tracking_number,
       s.shipped_date, s.expected_delivery, COALESCE(s.shipment_status, 'Not shipped') AS shipment_status,
       CONCAT(a.city, ', ', a.state) AS deliver_to
  FROM orders o
  JOIN address a       ON a.address_id = o.address_id
  LEFT JOIN shipment s ON s.order_id   = o.order_id
 WHERE o.order_status NOT IN ('Delivered', 'Cancelled');

-- Q4. LEFT JOIN: products that have never been ordered
SELECT p.product_code, p.product_name
  FROM product p
  LEFT JOIN order_item oi ON oi.product_id = p.product_id
 WHERE oi.order_item_id IS NULL;

-- Q5. SELF JOIN: category hierarchy (sub-category -> parent)
SELECT child.category_name AS sub_category, COALESCE(parent.category_name, '(top level)') AS parent_category
  FROM category child
  LEFT JOIN category parent ON parent.category_id = child.parent_category_id
 ORDER BY parent_category, sub_category;

-- Q6. AGGREGATION: sales by top-level category (excluding cancelled orders)
SELECT COALESCE(parent.category_name, cat.category_name) AS category,
       COUNT(DISTINCT oi.order_id)      AS orders,
       SUM(oi.quantity)                 AS units_sold,
       SUM(oi.quantity * oi.unit_price) AS sales
  FROM order_item oi
  JOIN orders o           ON o.order_id = oi.order_id AND o.order_status <> 'Cancelled'
  JOIN product p          ON p.product_id = oi.product_id
  JOIN category cat       ON cat.category_id = p.category_id
  LEFT JOIN category parent ON parent.category_id = cat.parent_category_id
 GROUP BY category
 ORDER BY sales DESC;

-- Q7. GROUP BY + HAVING: customers who placed more than one order
SELECT c.customer_id, CONCAT(c.first_name, ' ', c.last_name) AS customer, COUNT(*) AS orders
  FROM customer c JOIN orders o ON o.customer_id = c.customer_id
 GROUP BY c.customer_id, c.first_name, c.last_name
HAVING COUNT(*) > 1;

-- Q8. NESTED SUBQUERY: customers whose total spending is above the average order value
SELECT customer_name, SUM(order_total) AS total_spent
  FROM v_order_summary
 WHERE order_status <> 'Cancelled'
 GROUP BY customer_name
HAVING SUM(order_total) > (SELECT AVG(order_total) FROM v_order_summary WHERE order_status <> 'Cancelled')
 ORDER BY total_spent DESC;

-- Q9. CORRELATED SUBQUERY: products priced above the average of their own category
SELECT p.product_name, c.category_name, p.unit_price
  FROM product p JOIN category c ON c.category_id = p.category_id
 WHERE p.unit_price > (SELECT AVG(p2.unit_price) FROM product p2 WHERE p2.category_id = p.category_id);

-- Q10. NOT EXISTS: active products that have no reviews yet
SELECT p.product_code, p.product_name
  FROM product p
 WHERE p.is_active = TRUE
   AND NOT EXISTS (SELECT 1 FROM review r WHERE r.product_id = p.product_id);

-- Q11. IN subquery: orders that contain at least one returned item
SELECT order_number, customer_name, order_total
  FROM v_order_summary
 WHERE order_id IN (SELECT oi.order_id FROM order_item oi
                      JOIN return_request r ON r.order_item_id = oi.order_item_id);

-- Q12. Return rate per product (only products that were returned)
SELECT p.product_name,
       SUM(oi.quantity)                                    AS units_sold,
       SUM(COALESCE(r.quantity, 0))                        AS units_returned,
       ROUND(100 * SUM(COALESCE(r.quantity, 0)) / SUM(oi.quantity), 1) AS return_rate_pct
  FROM order_item oi
  JOIN product p ON p.product_id = oi.product_id
  LEFT JOIN return_request r ON r.order_item_id = oi.order_item_id AND r.return_status <> 'Rejected'
 GROUP BY p.product_id, p.product_name
HAVING units_returned > 0
 ORDER BY return_rate_pct DESC;

-- Q13. WINDOW FUNCTION: best-selling product in each seller's store
SELECT store_name, product_name, units_sold
  FROM (SELECT s.store_name, p.product_name, SUM(oi.quantity) AS units_sold,
               RANK() OVER (PARTITION BY s.seller_id ORDER BY SUM(oi.quantity) DESC) AS rnk
          FROM order_item oi
          JOIN orders o  ON o.order_id = oi.order_id AND o.order_status <> 'Cancelled'
          JOIN product p ON p.product_id = oi.product_id
          JOIN seller s  ON s.seller_id = p.seller_id
         GROUP BY s.seller_id, s.store_name, p.product_id, p.product_name) ranked
 WHERE rnk = 1;

-- Q14. Payment method mix for successful payments
SELECT payment_method, COUNT(*) AS payments, SUM(amount) AS amount
  FROM payment WHERE payment_status = 'Success'
 GROUP BY payment_method ORDER BY amount DESC;

-- Q15. Index check: the optimizer uses idx_order_status for a status search
EXPLAIN SELECT order_number FROM orders WHERE order_status = 'Shipped';
