# Data Dictionary

Generated from `database/01_schema.sql` (15 tables, 93 attributes).

## CUSTOMER

| Attribute | Data type | Key / constraint | Description |
|---|---|---|---|
| customer_id | INT | PK; AUTO_INCREMENT | Unique customer number |
| first_name | VARCHAR(50) | NOT NULL | Customer's first name |
| last_name | VARCHAR(50) | NOT NULL | Customer's last name |
| email | VARCHAR(100) | UNIQUE; CHECK email LIKE email format; NOT NULL | Login / contact email |
| phone | CHAR(10) | UNIQUE; CHECK phone REGEXP '^[6-9][0-9]{9}$'; NOT NULL | 10-digit mobile number |
| created_at | DATETIME | NOT NULL; DEFAULT CURRENT_TIMESTAMP | Registration time |

## ADDRESS

| Attribute | Data type | Key / constraint | Description |
|---|---|---|---|
| address_id | INT | PK; AUTO_INCREMENT | Unique address number |
| customer_id | INT | FK → customer; NOT NULL | Customer who owns the address |
| address_line | VARCHAR(150) | NOT NULL | House, street and area |
| city | VARCHAR(50) | NOT NULL | City |
| state | VARCHAR(50) | NOT NULL | State |
| pincode | CHAR(6) | CHECK pincode REGEXP '^[1-9][0-9]{5}$'; NOT NULL | Indian postal code |
| is_default | BOOLEAN | NOT NULL; DEFAULT FALSE | TRUE for the default address |

## SELLER

| Attribute | Data type | Key / constraint | Description |
|---|---|---|---|
| seller_id | INT | PK; AUTO_INCREMENT | Unique seller number |
| store_name | VARCHAR(100) | UNIQUE; NOT NULL | Store name shown to buyers |
| contact_name | VARCHAR(100) | NOT NULL | Seller's contact person |
| email | VARCHAR(100) | UNIQUE; CHECK email LIKE email format; NOT NULL | Seller email |
| phone | CHAR(10) | CHECK phone REGEXP '^[6-9][0-9]{9}$'; NOT NULL | Seller mobile number |
| gstin | CHAR(15) | UNIQUE; CHECK CHAR_LENGTH(gstin) = 15; NOT NULL | GST registration number |
| city | VARCHAR(50) | NOT NULL | Seller's city |
| joined_on | DATE | NOT NULL; DEFAULT CURRENT_DATE | Date the seller joined |

## CATEGORY

| Attribute | Data type | Key / constraint | Description |
|---|---|---|---|
| category_id | INT | PK; AUTO_INCREMENT | Unique category number |
| category_name | VARCHAR(60) | UNIQUE; NOT NULL | Category name |
| parent_category_id | INT | FK → category; NULL allowed | Parent category (NULL for top level) |

## PRODUCT

| Attribute | Data type | Key / constraint | Description |
|---|---|---|---|
| product_id | INT | PK; AUTO_INCREMENT | Unique product number |
| product_code | VARCHAR(20) | UNIQUE; NOT NULL | Seller product code (Rule 5) |
| seller_id | INT | FK → seller; NOT NULL | Seller who lists the product |
| category_id | INT | FK → category; NOT NULL | Category of the product |
| product_name | VARCHAR(120) | NOT NULL | Product name |
| description | VARCHAR(500) | NULL allowed | Short description |
| unit_price | DECIMAL(10,2) | CHECK unit_price > 0; NOT NULL | Current selling price in ₹ |
| return_window_days | INT | CHECK return_window_days BETWEEN 0 AND 30; NOT NULL; DEFAULT 7 | Days allowed for returns after delivery (Rule 3) |
| is_active | BOOLEAN | NOT NULL; DEFAULT TRUE | FALSE = discontinued, cannot be ordered |
| created_at | DATETIME | NOT NULL; DEFAULT CURRENT_TIMESTAMP | Time the product was listed |

## INVENTORY

| Attribute | Data type | Key / constraint | Description |
|---|---|---|---|
| inventory_id | INT | PK; AUTO_INCREMENT | Unique inventory record |
| product_id | INT | UNIQUE; FK → product; NOT NULL | Product this stock belongs to (1 : 1) |
| quantity_available | INT | CHECK quantity_available >= 0; NOT NULL; DEFAULT 0 | Units in stock (Rule 1) |
| reorder_level | INT | CHECK reorder_level >= 0; NOT NULL; DEFAULT 5 | Stock level that triggers a restock alert |
| last_updated | DATETIME | NOT NULL; DEFAULT CURRENT_TIMESTAMP | Time of the last stock change |

## CART

| Attribute | Data type | Key / constraint | Description |
|---|---|---|---|
| cart_id | INT | PK; AUTO_INCREMENT | Unique cart number |
| customer_id | INT | UNIQUE; FK → customer; NOT NULL | Owner of the cart (one cart each) |
| created_at | DATETIME | NOT NULL; DEFAULT CURRENT_TIMESTAMP | Time the cart was created |

## CART_ITEM

| Attribute | Data type | Key / constraint | Description |
|---|---|---|---|
| cart_item_id | INT | PK; AUTO_INCREMENT | Unique cart line |
| cart_id | INT | UNIQUE (cart_id, product_id); FK → cart; NOT NULL | Cart containing the line |
| product_id | INT | UNIQUE (cart_id, product_id); FK → product; NOT NULL | Product in the cart |
| quantity | INT | CHECK quantity > 0; NOT NULL; DEFAULT 1 | Units wanted |
| added_at | DATETIME | NOT NULL; DEFAULT CURRENT_TIMESTAMP | Time the item was added |

## ORDERS

| Attribute | Data type | Key / constraint | Description |
|---|---|---|---|
| order_id | INT | PK; AUTO_INCREMENT | Unique order number (internal) |
| order_number | VARCHAR(50) | UNIQUE; NOT NULL | Order number shown to users, e.g. ORD-000020 |
| customer_id | INT | FK → customer; NOT NULL | Customer who placed the order |
| address_id | INT | FK → address; NOT NULL | Delivery address |
| order_date | DATETIME | NOT NULL; DEFAULT CURRENT_TIMESTAMP | Time the order was placed |
| order_status | VARCHAR(20) | CHECK order_status IN ('Placed','Confirmed','Shipped','Delivered','Cancelled'); NOT NULL; DEFAULT 'Placed' | Lifecycle status of the order |

## ORDER_ITEM

| Attribute | Data type | Key / constraint | Description |
|---|---|---|---|
| order_item_id | INT | PK; AUTO_INCREMENT | Unique order line |
| order_id | INT | UNIQUE (order_id, product_id); FK → orders; NOT NULL | Order containing the line |
| product_id | INT | UNIQUE (order_id, product_id); FK → product; NOT NULL | Product ordered |
| quantity | INT | CHECK quantity > 0; NOT NULL | Units ordered (Rules 1, 2) |
| unit_price | DECIMAL(10,2) | CHECK unit_price > 0; NOT NULL | Price paid per unit at the time of ordering |

## PAYMENT

| Attribute | Data type | Key / constraint | Description |
|---|---|---|---|
| payment_id | INT | PK; AUTO_INCREMENT | Unique payment number |
| order_id | INT | UNIQUE; FK → orders; NOT NULL | Order paid for (one payment per order) |
| amount | DECIMAL(10,2) | CHECK amount > 0; NOT NULL | Amount paid = order total (Rule 4 limit) |
| payment_method | VARCHAR(20) | CHECK payment_method IN ('UPI','Card','NetBanking','COD'); NOT NULL | Payment method |
| payment_status | VARCHAR(20) | CHECK payment_status IN ('Pending','Success','Failed'); NOT NULL; DEFAULT 'Pending' | Result of the payment |
| transaction_ref | VARCHAR(40) | UNIQUE; NOT NULL | Gateway / bank reference |
| paid_at | DATETIME | NOT NULL; DEFAULT CURRENT_TIMESTAMP | Payment time |

## SHIPMENT

| Attribute | Data type | Key / constraint | Description |
|---|---|---|---|
| shipment_id | INT | PK; AUTO_INCREMENT | Unique shipment number |
| order_id | INT | UNIQUE; FK → orders; NOT NULL | Order being shipped (one per order) |
| courier_name | VARCHAR(50) | NOT NULL | Courier company |
| tracking_number | VARCHAR(30) | UNIQUE; NOT NULL | Courier tracking number |
| shipped_date | DATE | CHECK expected_delivery IS NULL OR shipped_date IS NULL OR expected_delivery >= shipped_date; CHECK delivered_date IS NULL OR (shipped_date IS NOT NULL AND delivered_date >= shipped_date); NULL allowed | Date handed to the courier |
| expected_delivery | DATE | CHECK expected_delivery IS NULL OR shipped_date IS NULL OR expected_delivery >= shipped_date; NULL allowed | Promised delivery date |
| delivered_date | DATE | CHECK delivered_date IS NULL OR (shipped_date IS NOT NULL AND delivered_date >= shipped_date); NULL allowed | Actual delivery date (starts the return window) |
| shipment_status | VARCHAR(20) | CHECK shipment_status IN ('Pending','Shipped','In Transit','Out for Delivery','Delivered'); NOT NULL; DEFAULT 'Pending' | Tracking status |

## RETURN_REQUEST

| Attribute | Data type | Key / constraint | Description |
|---|---|---|---|
| return_id | INT | PK; AUTO_INCREMENT | Unique return number |
| order_item_id | INT | FK → order_item; NOT NULL | Order line being returned |
| quantity | INT | CHECK quantity > 0; NOT NULL; DEFAULT 1 | Units returned (≤ units bought) |
| reason | VARCHAR(200) | NOT NULL | Customer's reason |
| request_date | DATE | NOT NULL; DEFAULT CURRENT_DATE | Date of request (within the window, Rule 3) |
| return_status | VARCHAR(20) | CHECK return_status IN ('Requested','Approved','Rejected','Received'); NOT NULL; DEFAULT 'Requested' | Admin decision / progress |
| decided_at | DATETIME | NULL allowed | Time of approval or rejection |

## REFUND

| Attribute | Data type | Key / constraint | Description |
|---|---|---|---|
| refund_id | INT | PK; AUTO_INCREMENT | Unique refund number |
| return_id | INT | UNIQUE; FK → return_request; NOT NULL | Return being refunded (one refund each) |
| refund_amount | DECIMAL(10,2) | CHECK refund_amount > 0; NOT NULL | Amount refunded (≤ value returned and amount paid, Rule 4) |
| refund_method | VARCHAR(20) | CHECK refund_method IN ('Original Payment','Bank Transfer','Store Credit'); NOT NULL; DEFAULT 'Original Payment' | Where the money is sent |
| refund_status | VARCHAR(20) | CHECK refund_status IN ('Initiated','Processed','Failed'); NOT NULL; DEFAULT 'Initiated' | Refund progress |
| initiated_at | DATETIME | NOT NULL; DEFAULT CURRENT_TIMESTAMP | Time the refund was started |
| processed_at | DATETIME | NULL allowed | Time the refund was paid out |

## REVIEW

| Attribute | Data type | Key / constraint | Description |
|---|---|---|---|
| review_id | INT | PK; AUTO_INCREMENT | Unique review number |
| customer_id | INT | UNIQUE (customer_id, product_id); FK → customer; NOT NULL | Customer who wrote the review |
| product_id | INT | UNIQUE (customer_id, product_id); FK → product; NOT NULL | Product reviewed |
| rating | TINYINT | CHECK rating BETWEEN 1 AND 5; NOT NULL | Rating from 1 to 5 |
| comment | VARCHAR(500) | NULL allowed | Review text |
| review_date | DATE | NOT NULL; DEFAULT CURRENT_DATE | Date of the review |
