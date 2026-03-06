
-- Expected packages for the morning window; each row has the cutoff_ts it belongs to.
CREATE TABLE last_expected_ts_package_events (
    package_id STRING,
    event_ts TIMESTAMP(3),
    status STRING,
    expected_ts TIMESTAMP(3),
    event_type STRING,
    payload STRING,
    PRIMARY KEY (package_id) NOT ENFORCED,
    WATERMARK FOR event_ts AS event_ts - INTERVAL '5' SECOND
) WITH (
    'changelog.mode' = 'upsert',
    'key.avro-registry.schema-context' = '.flink-dev',
    'value.avro-registry.schema-context' = '.flink-dev',
    'key.format' = 'avro-registry',
    'value.format' = 'avro-registry',
    'kafka.retention.time' = '1',
    'kafka.producer.compression.type' = 'snappy',
    'scan.startup.mode' = 'earliest-offset',
    'scan.bounded.mode' = 'unbounded',
    'value.fields-include' = 'all'
);
