# Test Cases

## Application tests (final demonstration)

| ID | Feature | Input / Action | Expected result | Actual result | Status |
|---|---|---|---|---|---|
| TC-01 | Catalogue search | Search "shoe" | Matching active products listed | Running Shoes (Men) listed | Pass |
| TC-02 | Create product | Add TN-ACC-003 Wireless Keyboard, stock 15 | Product and inventory created | "Product TN-ACC-003 added." | Pass |
| TC-03 | Unique code (Rule 5) | Add TN-ACC-003 again | Refused | "already exists" (error 1062) | Pass |
| TC-04 | Checkout transaction | Aarav Sharma: mouse × 1, skipping rope × 2, UPI | Order, items, payment created; cart emptied; stock reduced | ORD-000020, ₹1,993.00, UPI Success; stock 28→27, 53→51 | Pass |
| TC-05 | Stock (Rule 1) | Rohan Gupta: 50 dumbbells, 6 in stock | Refused, nothing saved | "Order quantity exceeds available stock." | Pass |
| TC-06 | Empty order (Rule 2) | Place order with an empty cart | Refused | "Cart is empty: an order needs at least one item." | Pass |
| TC-07 | Create shipment | ORD-000020, Delhivery, DL12345678 | Shipment saved; order Shipped | Order status Shipped | Pass |
| TC-08 | Delivery | Mark ORD-000013 Delivered | Order becomes Delivered (trigger) | Order status Delivered, 12 Oct 2026 | Pass |
| TC-09 | Return period (Rule 3) | Return phone from ORD-000001 (window ended 16 Aug) | Refused | "return period for this product has ended" | Pass |
| TC-10 | Valid return | Return book from ORD-000012 (window until 15 Oct) | Return request created | Return #7 Requested | Pass |
| TC-11 | Refund limit (Rule 4) | Refund ₹5,000 for jeans worth ₹1,499 | Refused | "Refund exceeds the value of the returned items." | Pass |
| TC-12 | Process refund | Mark refund #3 processed | Status Processed; date set by trigger | Processed 12 Oct 2026 | Pass |
| TC-13 | Reports | Open all seven report tabs | Each view returns data | All seven reports displayed | Pass |

## SQL-level tests (`database/06_rule_tests.sql`)

| Test | Rule | Action | Expected database response |
|---|---|---|---|
| T1 | 1 | Add 100 phones to an order (7 in stock) | Error 1644: Order quantity exceeds available stock. |
| T2 | 1 | Set stock to −1 | CHECK chk_inventory_qty violated |
| T3 | 1 | Checkout 50 dumbbells | Error 1644; stock unchanged (rollback) |
| T4 | 2 | Checkout with an empty cart | Error 1644: Cart is empty |
| T5 | 2 | Delete the only item of an order | Error 1644: order must contain at least one item |
| T6 | 2 | Order item with quantity 0 | CHECK chk_orderitem_qty violated |
| T7 | 3 | Return 63 days after delivery | Error 1644: return period has ended |
| T8 | 3 | Return an order in transit | Error 1644: not delivered yet |
| T9 | 3 | Return more units than bought | Error 1644: exceeds quantity purchased |
| T10 | 4 | Refund a return that is only Requested | Error 1644: approved or received return only |
| T11 | 4 | Refund ₹5,000 for a ₹1,499 item | Error 1644: exceeds value of returned items |
| T12 | 5 | Insert duplicate product code | Error 1062: duplicate entry |
| T13 | - | Rating 6 | CHECK chk_review_rating violated |
| T14 | - | Review without receiving the product | Error 1644: only customers who received it |
| T15 | - | Order for a non-existent customer | Error 1452: foreign key fails |
| T16 | - | Invalid phone number | CHECK chk_customer_phone violated |
| T17 | 1, 2 | Valid checkout (positive) | Order created; stock 28→27, 53→51; cart empty |
| T18 | 1 | Cancel an order (positive) | Stock restored 23→24 |
| T19 | 3, 4 | Valid return and refund (positive) | Return and refund accepted |
| T20 | - | Mark shipment delivered (positive) | Order status becomes Delivered |
