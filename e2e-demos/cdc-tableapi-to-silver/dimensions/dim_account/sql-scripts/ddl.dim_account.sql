CREATE TABLE IF NOT EXISTS dim_account (
    account_id STRING,
    account_name STRING,
    region STRING,
    created_at STRING,
    src_op STRING,
    is_deleted BOOLEAN,
    src_timestamp TIMESTAMP_LTZ(3),
    WATERMARK FOR src_timestamp AS src_timestamp - INTERVAL '5' SECOND,
    PRIMARY KEY (account_id) NOT ENFORCED
) DISTRIBUTED BY HASH(account_id) INTO 1 BUCKETS
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
