-- Raw accounts topic: mock Debezium envelope (source, before, after, op).
-- Used as source for src_accounts and dim_account pipeline.
CREATE TABLE IF NOT EXISTS raw_accounts (
    `key` VARBINARY(2147483647),
    `source` ROW<ts_ms BIGINT>,
    `before` ROW<
        account_id STRING,
        account_name STRING,
        region STRING,
        created_at STRING
    >,
    `after` ROW<
        account_id STRING,
        account_name STRING,
        region STRING,
        created_at STRING
    >,
    op STRING
) DISTRIBUTED BY HASH(`key`) INTO 1 BUCKETS
WITH (
    'changelog.mode' = 'append',
    'key.avro-registry.schema-context' = '.flink-dev',
    'value.avro-registry.schema-context' = '.flink-dev',
    'key.format' = 'avro-registry',
    'value.format' = 'avro-registry',
    'kafka.retention.time' = '0',
    'scan.bounded.mode' = 'unbounded',
    'scan.startup.mode' = 'earliest-offset',
    'value.fields-include' = 'all'
);
