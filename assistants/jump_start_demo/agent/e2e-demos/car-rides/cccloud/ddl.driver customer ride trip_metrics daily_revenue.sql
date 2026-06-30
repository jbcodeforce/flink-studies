-- Source table for topic raw_rides (car-rides demo)
-- Customize columns for your ride-sharing domain.
CREATE TABLE IF NOT EXISTS driver customer ride trip_metrics daily_revenue (
    driver customer ride trip_metrics daily_revenue_id STRING,
    event_time TIMESTAMP(3),
    payload STRING,
    WATERMARK FOR event_time AS event_time - INTERVAL '5' SECOND
) DISTRIBUTED BY (driver customer ride trip_metrics daily_revenue_id) INTO 4 BUCKETS
WITH (
    'key.format' = 'json-registry',
    'value.format' = 'json-registry',
    'kafka.consumer.isolation-level' = 'read-uncommitted'
);
