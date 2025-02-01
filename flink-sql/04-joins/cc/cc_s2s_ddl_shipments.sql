CREATE TABLE shipments (
    id VARCHAR,
    order_id INT,
    warehouse VARCHAR,
    ship_ts_raw BIGINT,  -- used as record ts, to process the events at any time and get a deterministic result
    PRIMARY KEY (id) NOT ENFORCED 
) DISTRIBUTED BY HASH(id) into 1 buckets WITH (
      'changelog.mode' = 'upsert',
      'key.format' = 'avro-registry',
      'value.format' = 'avro-registry',
      'value.fields-include' = 'all'
);