create table d04_enriched_orders (
    order_id INT,
    total_amount DOUBLE,
    customer_name VARCHAR,
    order_ts_raw TIMESTAMP(3),
    product_id INT,
    product_name STRING,
    primary key(order_id) not enforced
) distributed by(order_id) into 1 buckets
WITH (
   'changelog.mode' = 'upsert',
      'key.format' = 'avro-registry',
      'value.format' = 'avro-registry',
      'value.fields-include' = 'all'
);