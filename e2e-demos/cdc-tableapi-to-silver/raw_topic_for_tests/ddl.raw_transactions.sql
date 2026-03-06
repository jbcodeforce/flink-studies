-- Raw transactions topic: mock Debezium envelope (source, before, after, op).
-- Used as source for src_transactions and fct_transactions pipeline.
CREATE TABLE IF NOT EXISTS raw_transactions (
    `key` VARBINARY(2147483647),
    `source` ROW<ts_ms BIGINT>,
    `before` ROW<
        txn_id STRING,
        account_id STRING,
        amount DECIMAL(10, 2),
        currency STRING,
        ts STRING,
        status STRING
    >,
    `after` ROW<
        txn_id STRING,
        account_id STRING,
        amount DECIMAL(10, 2),
        currency STRING,
        ts STRING,
        status STRING
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
