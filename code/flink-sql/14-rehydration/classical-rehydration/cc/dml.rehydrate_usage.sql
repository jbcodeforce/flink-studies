-- Classical rehydration: rebuild keyed usage totals from the append event log.
INSERT INTO user_usage_summary
WITH deduped_events AS (
    SELECT
        key AS user_id,
        product_id,
        feature_id,
        usage_count,
        event_ts
    FROM (
        SELECT
            *,
            ROW_NUMBER() OVER (
                PARTITION BY event_id
                ORDER BY event_ts DESC
            ) AS row_num
        FROM usage_events
    )
    WHERE row_num = 1
)
SELECT
    coalesce(user_id, 'UNKNOWN') AS user_id,
    coalesce(product_id, 'UNKNOWN') AS product_id,
    coalesce(feature_id, 'UNKNOWN') AS feature_id,
    SUM(usage_count) AS total_usage,
    MAX(event_ts) AS last_event_time
FROM deduped_events
GROUP BY user_id, product_id, feature_id;
