-- Live incremental usage events (topic: usage-events)
-- event_time STRING payload uses yyyy-MM-dd HH:mm:ss.SSS (UTC) for CAST below.
CREATE TABLE IF NOT EXISTS usage_events (
    key STRING,
    product_id STRING,
    feature_id STRING,
    event_id STRING,
    usage_count BIGINT,
    event_time STRING,
    event_ts AS CAST(event_time AS TIMESTAMP_LTZ(3)),
    WATERMARK FOR event_ts AS event_ts - INTERVAL '5' SECOND
) DISTRIBUTED BY (key) INTO 4 BUCKETS
WITH (
    'changelog.mode' = 'append',
    'value.fields-include' = 'all',
    'value.format' = 'json-registry',
    'key.format' = 'raw'
);
