-- After editing this query, you MUST run `dbt run --full-refresh` to deploy the change.
-- Schema-drift detection only checks columns, types, and WITH options — query logic
-- changes are not detected and will be silently skipped on a normal `dbt run`.
--
-- Running GROUP BY aggregation (upsert changelog mode).
-- Joins reviews → listings → hosts to compute per-host monthly scorecards.
-- estimated_monthly_revenue uses review count × avg price as a proxy
-- (no booking data available in this dataset).
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
    review_date,
    review_sentiment
  FROM {{ ref('fct_reviews') }}
),

listings AS (
  SELECT
    listing_id,
    host_id,
    price
  FROM {{ ref('dim_listings_cleansed') }}
),

hosts AS (
  SELECT
    host_id,
    is_superhost
  FROM {{ ref('dim_hosts_cleansed') }}
),

review_listing AS (
  SELECT
    r.listing_id,
    l.host_id,
    l.price,
    CAST(
      SUBSTRING(r.review_date, 1, 7) || '-01' AS DATE
    )                   AS review_month,
    r.review_sentiment
  FROM reviews r
  INNER JOIN listings l ON r.listing_id = l.listing_id
)

SELECT
  rl.host_id,
  h.is_superhost,
  rl.review_month,
  COUNT(DISTINCT rl.listing_id)                                              AS active_listings,
  COUNT(*)                                                                   AS total_reviews,
  SUM(CASE WHEN rl.review_sentiment = 'positive' THEN 1 ELSE 0 END)         AS positive_reviews,
  SUM(CASE WHEN rl.review_sentiment = 'negative' THEN 1 ELSE 0 END)         AS negative_reviews,
  CAST(
    ROUND(
      100.0 * SUM(CASE WHEN rl.review_sentiment = 'positive' THEN 1 ELSE 0 END)
      / NULLIF(CAST(COUNT(*) AS DOUBLE), 0.0), 1
    ) AS DECIMAL(5, 1)
  )                                                                          AS sentiment_score,
  CAST(ROUND(AVG(rl.price), 2) AS DECIMAL(10, 2))                           AS avg_price,
  CAST(ROUND(CAST(COUNT(*) AS DOUBLE) * AVG(rl.price), 2) AS DECIMAL(14, 2)) AS estimated_monthly_revenue
FROM review_listing rl
INNER JOIN hosts h ON rl.host_id = h.host_id
GROUP BY rl.host_id, h.is_superhost, rl.review_month
