CREATE TABLE orders (
    id INT,
    total_amount DOUBLE,
    customer_name VARCHAR,
    order_ts_raw BIGINT  -- used as record ts, to process the events at any time and get a deterministic result
) WITH (
      'changelog.mode' = 'upsert',
      'key.format' = 'avro-registry',
      'value.format' = 'avro-registry',
      'value.fields-include' = 'all'
);