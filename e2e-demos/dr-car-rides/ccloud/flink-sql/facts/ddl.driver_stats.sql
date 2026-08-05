-- Per-driver tumbling window aggregates (stateful stage; Tableflow target)
CREATE TABLE IF NOT EXISTS driver_stats (
    driver_id STRING,
    window_start TIMESTAMP(3),
    window_end TIMESTAMP(3),
    ride_count BIGINT,
    fare_sum DOUBLE,
    max_seq BIGINT
) DISTRIBUTED BY (driver_id) INTO 6 BUCKETS
WITH (
    'key.format' = 'json-registry',
    'value.format' = 'json-registry',
    'value.fields-include' = 'all',
    'kafka.consumer.isolation-level' = 'read-uncommitted'
);
