-- Rolling feature sink: hop output keyed by user and feature time.
CREATE TABLE IF NOT EXISTS rolling_features (
    user_id STRING NOT NULL,
    feature_time TIMESTAMP(3) NOT NULL,
    cnt_6h BIGINT,
    cnt_12h BIGINT,
    amt_sum_6h DECIMAL(20, 2),
    amt_sum_12h DECIMAL(20, 2),
    PRIMARY KEY (user_id, feature_time) NOT ENFORCED
) DISTRIBUTED BY HASH(user_id) INTO 1 BUCKETS
WITH (
    'changelog.mode' = 'upsert',
    'kafka.cleanup-policy' = 'delete',
    'value.fields-include' = 'all',
    'scan.bounded.mode' = 'unbounded',
    'scan.startup.mode' = 'earliest-offset'
);
