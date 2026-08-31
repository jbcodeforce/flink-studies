# Complex Event Processing Examples

Those samples use dbt for deployment on Confluent Cloud, SQL client for Apache Flink.

## MATCH_RECOGNIZE

### Basic three-event pattern
Detect a temperature reading above 51, followed by one below 51, followed by one above 51.

* Confluent Cloud deployment
    ```sh
    dbt run --select 
    ```

### Detect three increasing values
The LAST() function compares the current event with the previous event assigned to the same pattern variable.

SELECT
  sensor_id,
  FIRST(UP.ts) AS start_ts,
  LAST(UP.ts) AS end_ts,
  ARRAY_AGG(UP.temperature) AS temperatures
FROM temperature_readings
MATCH_RECOGNIZE (
  PARTITION BY sensor_id
  ORDER BY ts

  MEASURES
    FIRST(UP.ts) AS start_ts,
    LAST(UP.ts) AS end_ts,
    ARRAY_AGG(UP.temperature) AS temperatures

  ONE ROW PER MATCH
  AFTER MATCH SKIP PAST LAST ROW

  PATTERN (UP{3})

  DEFINE
    UP AS
      COUNT(UP.temperature) = 1
      OR UP.temperature > LAST(UP.temperature, 1)
) AS MR;
sql

This detects sequences such as:

20 → 25 → 31
text

but not:

20 → 25 → 22
text

The first row is accepted unconditionally; subsequent rows must be greater than the previous UP value.  

### Detect an increasing trend followed by a decrease
SELECT
  sensor_id,
  FIRST(UP.ts) AS trend_start,
  LAST(UP.ts) AS trend_end,
  DOWN.ts AS drop_ts,
  LAST(UP.temperature) AS peak_temperature,
  DOWN.temperature AS drop_temperature
FROM temperature_readings
MATCH_RECOGNIZE (
  PARTITION BY sensor_id
  ORDER BY ts

  MEASURES
    FIRST(UP.ts) AS trend_start,
    LAST(UP.ts) AS trend_end,
    DOWN.ts AS drop_ts,
    LAST(UP.temperature) AS peak_temperature,
    DOWN.temperature AS drop_temperature

  ONE ROW PER MATCH
  AFTER MATCH SKIP PAST LAST ROW

  PATTERN (UP{3,} DOWN)

  DEFINE
    UP AS
      COUNT(UP.temperature) = 1
      OR UP.temperature > LAST(UP.temperature, 1),

    DOWN AS DOWN.temperature < LAST(UP.temperature, 1)
) AS MR;
sql

Example:

20 → 25 → 31 → 24
text

The UP{3,} quantifier requires at least three increasing readings before the decreasing reading.

### Detect a price drop within one hour
CREATE TABLE ticker (
  symbol STRING,
  price DECIMAL(10, 2),
  rowtime TIMESTAMP(3),

  WATERMARK FOR rowtime AS rowtime
);
sql

SELECT
  symbol,
  C.rowtime AS drop_time,
  A.price - C.price AS drop_amount
FROM ticker
MATCH_RECOGNIZE (
  PARTITION BY symbol
  ORDER BY rowtime

  MEASURES
    C.rowtime AS drop_time,
    A.price - C.price AS drop_amount

  ONE ROW PER MATCH
  AFTER MATCH SKIP PAST LAST ROW

  PATTERN (A B* C)
  WITHIN INTERVAL '1' HOUR

  DEFINE
    B AS B.price > A.price - 10,
    C AS C.price < A.price - 10
) AS MR;
sql

This identifies a price that falls by more than 10 within one hour. WITHIN limits the maximum duration of a potential match and helps bound state usage.  

### Detect two orders for the same product
SELECT
  customer_id,
  product_id,
  O1.order_time AS first_order_time,
  O2.order_time AS second_order_time
FROM orders
MATCH_RECOGNIZE (
  PARTITION BY customer_id, product_id
  ORDER BY order_time

  MEASURES
    O1.order_time AS first_order_time,
    O2.order_time AS second_order_time

  ONE ROW PER MATCH
  AFTER MATCH SKIP TO NEXT ROW

  PATTERN (O1 O2)
  WITHIN INTERVAL '60' DAYS

  DEFINE
    O1 AS TRUE,
    O2 AS TRUE
) AS MR;
sql

This finds customers who place a second order for the same product within 60 days. Partitioning by both customer and product keeps the pattern scoped correctly.  

### Session pattern: login followed by logout
SELECT
  user_id,
  L.login_time,
  O.logout_time
FROM user_events
MATCH_RECOGNIZE (
  PARTITION BY user_id
  ORDER BY event_time

  MEASURES
    L.event_time AS login_time,
    O.event_time AS logout_time

  ONE ROW PER MATCH
  AFTER MATCH SKIP PAST LAST ROW

  PATTERN (L EVENTS* O)
  WITHIN INTERVAL '24' HOUR

  DEFINE
    L AS L.event_type = 'LOGIN',
    EVENTS AS EVENTS.event_type <> 'LOGOUT',
    O AS O.event_type = 'LOGOUT'
) AS MR;
sql

This is useful for sessions delimited by explicit events such as LOGIN and LOGOUT; similar patterns can model connect/disconnect or start/stop workflows.  
