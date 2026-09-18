# Advanced Exercises — Joins & Aggregations

16 hands-on exercises using the Confluent Cloud **marketplace** sample dataset (`examples.marketplace.*`). Each exercise builds on join patterns introduced in the other demos and extends them with window aggregations, cross-join unnest, temporal joins, and UDFs.

SQL solutions for exercises 3 and above are in the `cc-flink/` folder. Exercises without a solution file are open-ended — write your own and deploy with `make deploy-pipeline`.

## Prerequisites

1. Access to the `examples.marketplace` catalog in your Confluent Cloud environment (source tables: `orders`, `products`, `product_details`, `customers`, `order_status`, `customer_inquiries`, `clicks`, `payments`, `categories`, `brands`)
2. Credentials configured in `../../../tools/`

## Run (Confluent Cloud)

```sh
cd cc-flink
make sync
# Deploy individual exercise SQL as needed, e.g.:
make deploy-pipeline
```

---

## Exercises

### 1 — Orders per customer per minute (non-overlapping tumble window)

```sql
CREATE TABLE order_count (
  PRIMARY KEY(customer_id) NOT ENFORCED
) AS
SELECT
  window_start,
  window_end,
  COALESCE(customer_id, 1) AS customer_id,
  COUNT(order_id) AS cnt
FROM TABLE(
  TUMBLE(TABLE `examples`.`marketplace`.`orders`, DESCRIPTOR(`$rowtime`), INTERVAL '1' MINUTE)
)
GROUP BY window_start, window_end, customer_id;
```

### 2 — Orders per product per minute (cross-join unnest on array column)

Orders have a `product_ids ARRAY<BIGINT>` column. Use `CROSS JOIN UNNEST` to expand the array before grouping by product:

```sql
CREATE TABLE order_counts AS
SELECT
  window_start,
  window_end,
  COUNT(order_id) AS cnt,
  window_time AS `$rowtime`
FROM TABLE(
  TUMBLE(TABLE `examples`.`marketplace`.`orders`, DESCRIPTOR(`$rowtime`), INTERVAL '1' MINUTE)
)
CROSS JOIN UNNEST(`product_ids`) AS product(product_id)
GROUP BY window_start, window_end, window_time, product_id;
```

### 3 — Average product volume per customer per minute

`product_details` contains a `dimensions` `ROW(length, width, height)`. Compute the average physical volume of products ordered per customer per minute.

See [`cc-3-avg-prod-volume-per-mn.sql`](./cc-flink/cc-3-avg-prod-volume-per-mn.sql).

```sql
CREATE TABLE order_volumes AS
WITH orders_with_details AS (
  SELECT o.order_id,
         s.dimensions.length,
         s.dimensions.height,
         s.dimensions.width,
         o.`$rowtime`
  FROM orders o
  CROSS JOIN UNNEST(o.product_ids) AS p(id)
  LEFT JOIN `product_details` FOR SYSTEM_TIME AS OF o.`$rowtime` s
    ON s.`product_id` = p.`id`
)
SELECT
  AVG(
    CAST(SPLIT_INDEX(length, 'c', 0) AS DOUBLE)
    * CAST(SPLIT_INDEX(width,  'c', 0) AS DOUBLE)
    * CAST(SPLIT_INDEX(height, 'c', 0) AS DOUBLE)
  ) AS avg_volume,
  window_time,
  o.order_id
FROM TABLE(
  TUMBLE(TABLE `orders_with_details`, DESCRIPTOR(`$rowtime`), INTERVAL '1' MINUTE)
) o
GROUP BY window_start, window_end, window_time, o.order_id;
```

### 4 — Rolling average order value (last 10 orders) per customer

Use an `OVER` window with `ROWS BETWEEN 9 PRECEDING AND CURRENT ROW` partitioned by `customer_id`.

### 5 — Total order value per order status at any given point in time

```sql
SELECT s.order_status, SUM(o.price) AS total
FROM orders o
INNER JOIN order_status s ON o.order_id = s.order_id
GROUP BY s.order_status;
```

> State is unbounded — apply `STATE_TTL` as appropriate for your use case.

### 6 — Order with product and customer info **as of the order time** (point-in-time join)

Use `FOR SYSTEM_TIME AS OF o.$rowtime` on `products` and `customers` to get the snapshot at the moment the order occurred.

### 7 — All up-to-date order information (regular multi-table join)

Join `orders`, `order_status`, `products`, `product_details`, `customers`, `categories`, and `brands`. Any update to any table should propagate to the result.

### 8 — Correlation between product category and payment method

Join `orders` to `payments` (on `order_id`) and to `categories` (via `products`), then `GROUP BY` and count.

### 9 — Customer inquiries enriched with product info and order status (point-in-time)

Use `FOR SYSTEM_TIME AS OF inquiry.$rowtime` to get the product and order state as of when the inquiry was created.

### 10 — ACTIVE/INACTIVE alert on customer inquiry volume

Send an `ACTIVE` alert to `alerts` when `COUNT(*) OVER (RANGE INTERVAL '30' MINUTE PRECEDING)` exceeds a threshold X. Retract it to `INACTIVE` when the condition is no longer met.

### 11 — Same product ordered twice in a row without another product in between

Use a self-join or `MATCH_RECOGNIZE` to detect the pattern `order_a → order_b` where both have the same `product_id` and no other product appears in between for the same customer.

### 12 — Same pattern as 11, but alert if repeat happens within 30 days regardless of intervening orders

Use an interval join or `MATCH_RECOGNIZE` with a `WITHIN 30 DAYS` clause.

### 13 — Session identification via clicks table

Use a session window (`SESSION(TABLE clicks, DESCRIPTOR($rowtime), INTERVAL '5' MINUTE)`) to compute session start, end, duration in seconds, and a list of visited URLs (`ARRAY_AGG`).

### 14 — Alert when rolling average session length drops

Compare `AVG(session_length) OVER (RANGE INTERVAL '5' MINUTE PRECEDING)` vs `AVG(session_length) OVER (RANGE INTERVAL '60' MINUTE PRECEDING)`. Emit an alert when the short-term average drops significantly below the long-term average.

### 15 — User-defined function: GENERATE_SERIES(BIGINT, BIGINT)

Implement a UDF returning `ARRAY<BIGINT>`. See the [Confluent UDF guide](https://docs.confluent.io/cloud/current/flink/how-to-guides/create-udf.html).

### 16 — Improve ValidateProductName UDF

Extend the function to return a structured error object (not just a boolean) indicating *why* a product name is invalid, with `NULL` when the name is valid.
