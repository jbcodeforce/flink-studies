create table transactions (
    transaction_id STRING,
    user_id STRING,
    amount DECIMAL(12, 2),
    ts TIMESTAMP(3),
    WATERMARK FOR ts AS ts - INTERVAL '5' SECOND,
    PRIMARY KEY (transaction_id) NOT ENFORCED
) distributed by hash(transaction_id) into 1 buckets with (
    'changelog.mode' = 'append',
    'key.format' = 'avro-registry',
    'value.format' = 'avro-registry',
    'scan.bounded.mode' = 'unbounded',
    'kafka.cleanup-policy' = 'delete',
    'scan.startup.mode' = 'earliest-offset',
    'value.fields-include' = 'all'
);