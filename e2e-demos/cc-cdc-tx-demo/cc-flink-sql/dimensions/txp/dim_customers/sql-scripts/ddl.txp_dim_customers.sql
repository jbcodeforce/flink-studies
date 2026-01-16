CREATE TABLE IF NOT EXISTS txp_dim_customers (
    account_number STRING,
    customer_name STRING,
    email STRING,
    phone_number STRING,
    date_of_birth STRING,
    city STRING,
    created_at STRING,
    src_op STRING,
    is_deleted BOOLEAN,
    src_timestamp TIMESTAMP_LTZ(3),
    -- Watermark for event-time processing
    WATERMARK FOR src_timestamp AS src_timestamp - INTERVAL '5' SECOND,
    -- Primary key for upsert semantics
    PRIMARY KEY (account_number) NOT ENFORCED
) DISTRIBUTED BY HASH (account_number) INTO 1 BUCKETS WITH (
  'changelog.mode' = 'upsert',
  'key.avro-registry.schema-context' = '.flink-dev',
  'value.avro-registry.schema-context' = '.flink-dev',
  'key.format' = 'avro-registry',
  'value.format' = 'avro-registry',
  'kafka.retention.time' = '0',
  'kafka.producer.compression.type' = 'snappy',
  'scan.bounded.mode' = 'unbounded',
  'scan.startup.mode' = 'earliest-offset',
  'value.fields-include' = 'all'
);
