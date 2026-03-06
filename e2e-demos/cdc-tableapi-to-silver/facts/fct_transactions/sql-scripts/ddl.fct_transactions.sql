CREATE TABLE IF NOT EXISTS fct_transactions (
    txn_id STRING,
    account_id STRING,
    amount DECIMAL(10, 2),
    currency STRING,
    `timestamp` TIMESTAMP_LTZ(3),
    status STRING,
    WATERMARK FOR `timestamp` AS `timestamp` - INTERVAL '5' SECOND,
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
