CREATE TABLE IF NOT EXISTS txp_dim_enriched_tx (
  txn_id STRING,
    `timestamp` TIMESTAMP_LTZ(3),
    amount DECIMAL(10, 2),
    currency STRING,
    merchant STRING,
    location STRING,
    status STRING,
    transaction_type STRING,
    -- Customer fields
    account_number STRING,
    customer_name STRING,
    customer_email STRING,
    customer_city STRING,
    -- ML enrichment fields
    fraud_score DOUBLE,
    fraud_category STRING,
    risk_level STRING,
    -- Processing metadata
    enriched_at TIMESTAMP_LTZ(3),
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