-- Mix historical snapshots with live events; live rows win for the same key.
INSERT INTO unified_user_usage
WITH combined AS (
    SELECT
        key as user_id,
        product_id,
        feature_id,
        usage_count,
        event_ts,
        CAST('snapshot' AS STRING) AS source_type
    FROM usage_snapshots
    UNION ALL
    SELECT
        key as user_id,
        product_id,
        feature_id,
        usage_count,
        event_ts,
        CAST('live' AS STRING) AS source_type
    FROM usage_events
),
ranked AS (
    SELECT
        user_id,
        product_id,
        feature_id,
        usage_count,
        event_ts,
        source_type,
        ROW_NUMBER() OVER (
            PARTITION BY user_id, product_id, feature_id
            ORDER BY
                CASE source_type WHEN 'live' THEN 1 ELSE 2 END,
                event_ts DESC
        ) AS row_num
    FROM combined
)
SELECT
    coalesce(user_id, 'UNKNOWN') AS user_id,
    coalesce(product_id, 'UNKNOWN') AS product_id,
    coalesce(feature_id, 'UNKNOWN') AS feature_id,
    usage_count,
    event_ts AS last_event_time,
    source_type
FROM ranked
WHERE row_num = 1;
