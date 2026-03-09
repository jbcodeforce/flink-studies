CREATE TABLE IF NOT EXISTS src_txp_transaction (
    txn_id STRING,
    account_number STRING,
    `timestamp` TIMESTAMP_LTZ(3),
    amount DECIMAL(10, 2),
    currency STRING,
    merchant STRING,
    location STRING,
    status STRING,
    transaction_type STRING,
    -- Metadata from Kafka
    src_partition INT,
    src_offset BIGINT,
    -- Watermark for event-time processing
    WATERMARK FOR `timestamp` AS `timestamp` - INTERVAL '5' SECOND,
    -- Primary key for upsert semantics
    PRIMARY KEY (txn_id) NOT ENFORCED
) DISTRIBUTED BY HASH(txn_id) INTO 1 BUCKETS
WITH (
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