CREATE TABLE d04_products (
    id int,
    product_name STRING,
    product_ts_raw TIMESTAMP(3),  -- used as record ts, to process the events at any time and get a deterministic result
    PRIMARY KEY (id) NOT ENFORCED,
    WATERMARK FOR product_ts_raw AS product_ts_raw - INTERVAL '5' SECOND
) DISTRIBUTED BY HASH(id) into 1 buckets WITH (
      'changelog.mode' = 'upsert',
      'key.format' = 'avro-registry',
      'value.format' = 'avro-registry',
      'value.fields-include' = 'all'
);