# Normalization up to 3NF

**Unnormalized order record**

ORDER_RECORD(order_no, order_date, customer_name, customer_email, customer_phone, address,
{ product_code, product_name, seller_name, seller_gstin, category, price, qty },
payment_method, amount, courier, tracking_no, return_reason, refund_amount)

**1NF.** The repeating product group is removed: one row per product of the order, with key (order_no, product_code). Values are made atomic (first_name / last_name).

**2NF.** Partial dependencies are removed:
- order_no → date, customer, payment, shipment details: **ORDERS**
- product_code → name, price, seller, category: **PRODUCT**
- (order_no, product_code) → qty, unit_price: **ORDER_ITEM**

**3NF.** Transitive dependencies are removed:
- order → customer_id → name, email, phone: **CUSTOMER** (+ **ADDRESS** for many addresses)
- product → seller_id → store_name, gstin: **SELLER**
- product → category_id → category_name: **CATEGORY** (recursive parent)
- order → payment facts / shipment facts: **PAYMENT**, **SHIPMENT** (1 : 1)
- order item → return facts → refund facts: **RETURN_REQUEST**, **REFUND**
- stock changes often: **INVENTORY** (1 : 1 with PRODUCT)

**Design decisions**
- Order total is derived (view `v_order_summary`), not stored.
- ORDER_ITEM.unit_price is the price on the day of purchase, not a copy of PRODUCT.unit_price.
- Business records are never deleted; status columns record their lifecycle.

Result: 15 relations, all in 3NF (and BCNF).
