-- Two-stage windowing demo: tumble into hourly buckets, then hop for rolling features.
-- Pattern: coarse TUMBLE reduces row count; HOP(slide = tumble) keeps output cadence;
-- shorter lookback uses CASE on bucket_end vs window_end (same idea as 1d/3d/7d inside a 30d hop).
--
-- Run in Flink SQL Client (see ../readme.md). Bounded datagen finishes after number-of-rows.
-- Batch mode + print sink: submit with a running cluster (`start-cluster.sh` then `sql-client.sh -f`).

SET 'execution.runtime-mode' = 'batch';

CREATE TEMPORARY TABLE events (
    user_id STRING,
    amount DECIMAL(10, 2),
    seq BIGINT,
    event_time AS TO_TIMESTAMP_LTZ(seq * 60000, 3),
    WATERMARK FOR event_time AS event_time - INTERVAL '1' SECOND
) WITH (
    'connector' = 'datagen',
    'number-of-rows' = '4000',
    'rows-per-second' = '400',
    'fields.user_id.length' = '4',
    'fields.amount.min' = '1.00',
    'fields.amount.max' = '100.00',
    'fields.seq.kind' = 'sequence',
    'fields.seq.start' = '1',
    'fields.seq.end' = '10000000'
);

CREATE TEMPORARY TABLE rolling_features (
    user_id STRING,
    feature_time TIMESTAMP(3),
    cnt_6h BIGINT,
    cnt_12h BIGINT,
    amt_sum_6h DECIMAL(20, 2),
    amt_sum_12h DECIMAL(20, 2)
) WITH ('connector' = 'print');

INSERT INTO rolling_features
WITH base AS (
    SELECT user_id, amount, event_time
    FROM events
),

bucket_1h AS (
    SELECT
        user_id,
        window_end AS bucket_end,
        window_time AS bucket_time,
        COUNT(*) AS cnt,
        SUM(amount) AS amt_sum
    FROM TABLE(
        TUMBLE(
            TABLE base,
            DESCRIPTOR(event_time),
            INTERVAL '1' HOUR
        )
    )
    GROUP BY user_id, window_start, window_end, window_time
),

agg AS (
    SELECT
        user_id,
        window_end AS feature_time,
        SUM(CASE WHEN bucket_end >= window_end - INTERVAL '6' HOUR THEN cnt END) AS cnt_6h,
        SUM(cnt) AS cnt_12h,
        SUM(CASE WHEN bucket_end >= window_end - INTERVAL '6' HOUR THEN amt_sum END) AS amt_sum_6h,
        SUM(amt_sum) AS amt_sum_12h
    FROM TABLE(
        HOP(
            TABLE bucket_1h,
            DESCRIPTOR(bucket_time),
            INTERVAL '1' HOUR,
            INTERVAL '12' HOUR
        )
    )
    GROUP BY user_id, window_start, window_end
)
SELECT
    user_id,
    feature_time,
    cnt_6h,
    cnt_12h,
    amt_sum_6h,
    amt_sum_12h
FROM agg;
