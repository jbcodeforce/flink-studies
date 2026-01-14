CREATE TABLE IF NOT EXISTS txp_fct_hourly_tx_metrics (
    account_number STRING,
    window_start TIMESTAMP(3),
    window_end TIMESTAMP(3),
    window_type STRING,
    tx_count BIGINT,
    total_amount DECIMAL(10, 2),
    avg_amount DECIMAL(10, 2),
    min_amount DECIMAL(10, 2),
    max_amount DECIMAL(10, 2),
    PRIMARY KEY(account_number, window_start, window_type) NOT ENFORCED
) DISTRIBUTED BY HASH(account_number, window_start, window_type) INTO 1 BUCKETS WITH (
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