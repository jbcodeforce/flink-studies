{{
  config(
    materialized = 'table'
  )
}}

WITH reviews AS (
  SELECT
    listing_id,
    review_date,
    review_sentiment
  FROM {{ ref('fct_reviews') }}
),

full_moon_dates AS (
  SELECT full_moon_date FROM {{ ref('seed_full_moon_dates') }}
),

reviews_with_moon AS (
  SELECT
    r.listing_id,
    CAST(DATE_TRUNC('month', r.review_date) AS DATE) AS review_month,
    r.review_sentiment,
    CASE WHEN fm.full_moon_date IS NOT NULL THEN 1 ELSE 0 END AS is_full_moon
  FROM reviews r
  LEFT JOIN full_moon_dates fm
    ON CAST(r.review_date AS DATE) = fm.full_moon_date
)

SELECT
  listing_id,
  review_month,
  COUNT(*)                                                         AS total_reviews,
  SUM(CASE WHEN review_sentiment = 'positive' THEN 1 ELSE 0 END)  AS positive_reviews,
  SUM(CASE WHEN review_sentiment = 'neutral'  THEN 1 ELSE 0 END)  AS neutral_reviews,
  SUM(CASE WHEN review_sentiment = 'negative' THEN 1 ELSE 0 END)  AS negative_reviews,
  ROUND(
    100.0 * SUM(CASE WHEN review_sentiment = 'positive' THEN 1 ELSE 0 END)
    / NULLIF(COUNT(*), 0), 1
  )                                                                AS positive_pct,
  SUM(is_full_moon)                                                AS full_moon_reviews
FROM reviews_with_moon
GROUP BY listing_id, review_month
