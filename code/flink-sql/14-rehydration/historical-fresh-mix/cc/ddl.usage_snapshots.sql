-- Historical bulk snapshot of SaaS usage (topic: usage-snapshots)
-- json-registry maps date-time JSON fields to STRING; cast before watermarking.
CREATE TABLE IF NOT EXISTS usage_snapshots (
    key STRING,
    product_id STRING,
    feature_id STRING,
    usage_count BIGINT,
    snapshot_ts STRING,
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
