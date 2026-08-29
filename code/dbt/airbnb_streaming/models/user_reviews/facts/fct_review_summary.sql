-- After editing this query, you MUST run `dbt run --full-refresh` to deploy the change.
-- Schema-drift detection only checks columns, types, and WITH options — query logic
-- changes are not detected and will be silently skipped on a normal `dbt run`.
--
-- Running GROUP BY aggregation (upsert changelog mode).
-- review_month is derived from the varchar review_date by truncating to the
-- first day of the month, compatible with Flink SQL string operations.
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
    review_date as review_date_str,
    CAST(SUBSTRING(review_date, 1, 10) AS DATE) as review_date,
    review_sentiment
  FROM {{ ref('fct_reviews') }}
),

full_moon AS (
  SELECT full_moon_date FROM {{ ref('seed_full_moon_dates') }}
),

reviews_enriched AS (
  SELECT
    r.listing_id,
    CAST(
      SUBSTRING(r.review_date_str, 1, 7) || '-01' AS DATE
    )                                                      AS review_month,
    r.review_sentiment,
    CASE
      WHEN fm.full_moon_date IS NOT NULL THEN 1
      ELSE 0
    END                                                    AS is_full_moon_review
  FROM reviews r
  LEFT JOIN full_moon fm
    ON r.review_date = fm.full_moon_date
)

SELECT
  listing_id,
  review_month,
  COUNT(*)                                                                      AS total_reviews,
  SUM(CASE WHEN review_sentiment = 'positive' THEN 1 ELSE 0 END)               AS positive_reviews,
  SUM(CASE WHEN review_sentiment = 'neutral'  THEN 1 ELSE 0 END)               AS neutral_reviews,
  SUM(CASE WHEN review_sentiment = 'negative' THEN 1 ELSE 0 END)               AS negative_reviews,
  CAST(
    ROUND(
      100.0 * SUM(CASE WHEN review_sentiment = 'positive' THEN 1 ELSE 0 END)
      / NULLIF(CAST(COUNT(*) AS DOUBLE), 0.0), 1
    ) AS DECIMAL(5, 1)
  )                                                                             AS positive_pct,
  SUM(is_full_moon_review)                                                      AS full_moon_reviews
FROM reviews_enriched
GROUP BY listing_id, review_month
