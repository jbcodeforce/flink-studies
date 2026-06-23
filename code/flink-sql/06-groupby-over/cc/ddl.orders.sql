-- Append-only source for OVER window demos (OVER does not support retract/update semantics).
CREATE TABLE IF NOT EXISTS d06_orders (
    order_id INT NOT NULL,
    customer_id INT,
    customer_name VARCHAR,
    order_ts TIMESTAMP(3),
    total_amount DOUBLE,
    PRIMARY KEY (order_id) NOT ENFORCED,
    WATERMARK FOR order_ts AS order_ts - INTERVAL '5' SECOND
) DISTRIBUTED BY HASH(order_id) INTO 1 BUCKETS
WITH (
    'changelog.mode' = 'append',
    'key.format' = 'avro-registry',
    'value.format' = 'avro-registry',
    'value.fields-include' = 'all',
    'scan.bounded.mode' = 'unbounded',
    'scan.startup.mode' = 'earliest-offset'
);
