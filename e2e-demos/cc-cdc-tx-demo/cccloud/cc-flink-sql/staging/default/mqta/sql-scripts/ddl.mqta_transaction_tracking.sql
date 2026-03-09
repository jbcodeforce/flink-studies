
CREATE TABLE IF NOT EXISTS transaction_tracking (
    server_uuid STRING,
    loadable_begin INTEGER,
    loadable_end INTEGER,
    complete_begin INTEGER,
    complete_end INTEGER,
    incomplete_begin INTEGER,
    incomplete_end INTEGER,
    contiguous_begin INTEGER,
    contiguous_end INTEGER,
    noncontiguous_begin INTEGER,
    noncontiguous_end INTEGER,
    old_enough_begin INTEGER,
    old_enough_end INTEGER,
    missing_old_transactions INTEGER,
    overcomplete_transactions INTEGER,
    PRIMARY KEY(server_uuid) NOT ENFORCED
) DISTRIBUTED BY HASH(server_uuid) INTO 1 BUCKETS WITH (
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
)
