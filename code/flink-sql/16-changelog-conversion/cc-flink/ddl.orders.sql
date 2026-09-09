-- Materialised Flink updating table produced by FROM_CHANGELOG.
-- FROM_CHANGELOG reads d16_raw_orders, maps the 'op' field to Flink row kinds,
-- and writes the result here.  Downstream queries and TO_CHANGELOG read from
-- this table instead of directly from FROM_CHANGELOG to avoid the known
-- limitation where a foreground SELECT on a FROM_CHANGELOG upsert output can
-- silently return wrong results.
CREATE TABLE IF NOT EXISTS d16_orders (
    order_id    INT         NOT NULL,
    user_id     STRING,
    product_id  STRING,
    quantity    INT,
    amount      DOUBLE,
    PRIMARY KEY (order_id) NOT ENFORCED
) DISTRIBUTED BY HASH(order_id) INTO 2 BUCKETS
WITH (
    'changelog.mode'        = 'upsert',
    'key.format'            = 'avro-registry',
    'value.format'          = 'avro-registry',
    'value.fields-include'  = 'all',
    'scan.startup.mode'     = 'earliest-offset',
    'scan.bounded.mode'     = 'unbounded'
);
