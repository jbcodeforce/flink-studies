CREATE TABLE IF NOT EXISTS `d04_orders` (
    id INT,
    total_amount DOUBLE,
    customer_name VARCHAR,
    order_ts_raw TIMESTAMP(3),
    product_id INT,
    PRIMARY KEY (id) NOT ENFORCED,
    WATERMARK FOR order_ts_raw AS order_ts_raw - INTERVAL '5' SECOND
) DISTRIBUTED BY HASH(id) into 1 buckets WITH (
      'changelog.mode' = 'upsert',
      'key.format' = 'avro-registry',
      'value.format' = 'avro-registry',
      'value.fields-include' = 'all'
);