# Functional Dependencies

Every determinant below is the primary key or another candidate key of its relation, so every relation is in BCNF (and therefore 3NF).

| Relation | Functional dependency |
|---|---|
| CUSTOMER | customer_id → first_name, last_name, email, phone, created_at; email → customer_id; phone → customer_id |
| ADDRESS | address_id → customer_id, address_line, city, state, pincode, is_default |
| SELLER | seller_id → store_name, contact_name, email, phone, gstin, city, joined_on; gstin → seller_id; store_name → seller_id |
| CATEGORY | category_id → category_name, parent_category_id; category_name → category_id |
| PRODUCT | product_id → product_code, seller_id, category_id, product_name, description, unit_price, return_window_days, is_active, created_at; product_code → product_id |
| INVENTORY | product_id → quantity_available, reorder_level, last_updated |
| CART | customer_id → cart_id, created_at |
| CART_ITEM | (cart_id, product_id) → quantity, added_at |
| ORDERS | order_id → order_number, customer_id, address_id, order_date, order_status; order_number → order_id |
| ORDER_ITEM | (order_id, product_id) → quantity, unit_price |
| PAYMENT | order_id → amount, payment_method, payment_status, transaction_ref, paid_at |
| SHIPMENT | order_id → courier_name, tracking_number, shipped_date, expected_delivery, delivered_date, shipment_status |
| RETURN_REQUEST | return_id → order_item_id, quantity, reason, request_date, return_status, decided_at |
| REFUND | return_id → refund_amount, refund_method, refund_status, initiated_at, processed_at |
| REVIEW | (customer_id, product_id) → rating, comment, review_date |
