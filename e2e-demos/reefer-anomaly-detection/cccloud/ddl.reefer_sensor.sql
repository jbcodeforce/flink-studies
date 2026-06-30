-- Source table for topic reefer-sensors (reefer-anomaly-detection demo)
-- Customize columns for your healthcare domain.
CREATE TABLE IF NOT EXISTS reefer_sensor (
    reefer_sensor_id STRING,
    event_time TIMESTAMP(3),
    payload STRING,
    WATERMARK FOR event_time AS event_time - INTERVAL '5' SECOND
) DISTRIBUTED BY (reefer_sensor_id) INTO 4 BUCKETS
WITH (
    'key.format' = 'json-registry',
    'value.format' = 'json-registry',
    'kafka.consumer.isolation-level' = 'read-uncommitted'
);
