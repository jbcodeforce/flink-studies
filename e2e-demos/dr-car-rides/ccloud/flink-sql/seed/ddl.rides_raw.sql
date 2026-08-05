-- Raw car-ride events (producer writes here; Cluster Link mirrors to DR)
CREATE TABLE IF NOT EXISTS rides_raw (
    driver_id STRING,
    ride_id STRING,
    seq BIGINT,
    rider_id STRING,
    pickup_ts TIMESTAMP(3),
    fare_usd DOUBLE,
    status STRING,
    city STRING,
    WATERMARK FOR pickup_ts AS pickup_ts - INTERVAL '5' SECOND
) DISTRIBUTED BY (driver_id) INTO 6 BUCKETS
WITH (
    'key.format' = 'json-registry',
    'value.format' = 'json-registry',
    'value.fields-include' = 'all',
    'kafka.consumer.isolation-level' = 'read-uncommitted'
);
