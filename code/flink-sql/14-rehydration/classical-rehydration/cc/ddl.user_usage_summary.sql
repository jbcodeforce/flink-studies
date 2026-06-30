-- Rehydrated current-state sink: one row per user + product + feature.
CREATE TABLE IF NOT EXISTS user_usage_summary (
    user_id STRING NOT NULL,
    product_id STRING NOT NULL,
    feature_id STRING NOT NULL,
    total_usage BIGINT,
    last_event_time TIMESTAMP_LTZ(3),
    PRIMARY KEY (user_id, product_id, feature_id) NOT ENFORCED
) DISTRIBUTED BY (user_id, product_id, feature_id) INTO 4 BUCKETS
WITH (
    'changelog.mode' = 'upsert',
    'scan.startup.mode' = 'earliest-offset',
    'kafka.cleanup-policy' = 'compact',
    'value.fields-include' = 'all',
    'key.format' = 'json-registry',
    'value.format' = 'json-registry'
);
