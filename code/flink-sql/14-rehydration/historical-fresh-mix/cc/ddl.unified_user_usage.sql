-- Unified current-state view combining historical snapshots and live usage.
CREATE TABLE IF NOT EXISTS unified_user_usage (
    user_id STRING NOT NULL,
    product_id STRING NOT NULL,
    feature_id STRING NOT NULL,
    usage_count BIGINT,
    last_event_time TIMESTAMP_LTZ(3),
    source_type STRING,
    PRIMARY KEY (user_id, product_id, feature_id) NOT ENFORCED
) DISTRIBUTED BY (user_id, product_id, feature_id) INTO 4 BUCKETS
WITH (
    'changelog.mode' = 'upsert',
    'scan.startup.mode' = 'earliest-offset',
    'value.fields-include' = 'all',
    'key.format' = 'json-registry',
    'value.format' = 'json-registry'
);
