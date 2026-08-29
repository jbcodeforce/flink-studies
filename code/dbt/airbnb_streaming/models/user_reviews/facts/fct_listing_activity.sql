-- After editing this query, you MUST run `dbt run --full-refresh` to deploy the change.
-- Schema-drift detection only checks columns, types, and WITH options — query logic
-- changes are not detected and will be silently skipped on a normal `dbt run`.
--
-- Running GROUP BY aggregation (upsert changelog mode).
-- Tracks per-listing review velocity, recency, and activity status.
-- review_date arrives as varchar and is cast to DATE for date arithmetic.
{{ config(
    materialized = 'streaming_table',
    with= {
        'changelog.mode': 'upsert',
        'connector': 'confluent',
        'kafka.cleanup-policy': 'delete',
        'kafka.compaction.time': '0 ms',
        'kafka.max-message-size': '2097164 bytes',
        'kafka.retention.size': '0 bytes',
        'kafka.retention.time': '0 ms',
        'scan.bounded.mode': 'unbounded',
        'scan.startup.mode': 'earliest-offset',
        'value.format': 'avro-registry'
    }
) }}

WITH reviews AS (
  SELECT
    listing_id,
    CAST(SUBSTRING(review_date, 1, 10)  AS TIMESTAMP_LTZ) AS review_date,
    `$rowtime` as current_ts
  FROM {{ ref('fct_reviews') }}
),

listings AS (
  SELECT
    listing_id,
    host_id,
    room_type,
    price
  FROM {{ ref('dim_listings_cleansed') }}
),

review_agg AS (
  SELECT
    listing_id,
    MIN(review_date)  AS first_review_date,
    MAX(review_date)  AS last_review_date,
    COUNT(*)          AS total_reviews,
    MAX(current_ts)   AS current_ts
  FROM reviews
  GROUP BY listing_id
)

SELECT
  l.listing_id,
  l.host_id,
  l.room_type,
  l.price,
  r.first_review_date,
  r.last_review_date,
  r.total_reviews,
  TIMESTAMPDIFF(DAY, r.first_review_date, r.last_review_date)           AS days_active,
  CAST(
    CAST(TIMESTAMPDIFF(DAY, r.first_review_date, r.last_review_date) AS DOUBLE)
    / NULLIF(CAST(r.total_reviews - 1 AS DOUBLE), 0.0)
    AS DECIMAL(10, 1)
  )                                                                      AS avg_days_between_reviews,
  TIMESTAMPDIFF(DAY, r.last_review_date, r.current_ts)                  AS days_since_last_review,
  CASE
    WHEN r.total_reviews <= 3                                                       THEN 'New'
    WHEN TIMESTAMPDIFF(DAY, r.last_review_date, r.current_ts) <= 180               THEN 'Active'
    ELSE                                                                                 'Dormant'
  END                                                                    AS activity_status
FROM listings l
INNER JOIN review_agg r ON l.listing_id = r.listing_id
