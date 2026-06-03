-- Stage A: 1h tumble buckets. Stage B: 12h hop (1h slide); 6h metrics via CASE on bucket_end.
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
