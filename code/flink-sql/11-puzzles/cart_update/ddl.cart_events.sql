-- Raw cart add/remove events (append). Deduped into cart_line_items by dml.build_cart_line_items.sql.
CREATE TABLE IF NOT EXISTS cart_events (
    cart_id STRING,
    product_id STRING,
    action STRING,
    quantity INT,
    cart_status STRING,
    cart_date DATE,
    user_id STRING,
    event_ts TIMESTAMP_LTZ(3)
) DISTRIBUTED INTO 1 BUCKETS
WITH (
    'changelog.mode' = 'append',
    'value.fields-include' = 'all',
    'scan.bounded.mode' = 'unbounded',
    'scan.startup.mode' = 'earliest-offset'
);
