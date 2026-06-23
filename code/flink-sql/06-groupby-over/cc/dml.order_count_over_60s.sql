-- Rolling order count per customer over the last 10 seconds (one output row per input row).
CREATE TABLE d06_order_count_over_60s(
  PRIMARY KEY (customer_id) NOT ENFORCED
) WITH (
    'changelog.mode' = 'upsert',
    'key.format' = 'avro-registry',
    'value.format' = 'avro-registry',
    'value.fields-include' = 'all'
) 
AS
SELECT
    order_id,
    coalesce(customer_id,0) as customer_id,
    customer_name,
    order_ts,
    total_amount,
    COUNT(*) OVER w AS order_count_60s
FROM d06_orders
WINDOW w AS (
    PARTITION BY customer_id
    ORDER BY order_ts
    RANGE BETWEEN INTERVAL '60' SECONDS PRECEDING AND CURRENT ROW
);
