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
    CAST(DATE_TRUNC('month', r.review_date) AS DATE) AS review_month,
    r.review_sentiment
  FROM reviews r
  INNER JOIN listings l ON r.listing_id = l.listing_id
)

SELECT
  rl.host_id,
  h.is_superhost,
  rl.review_month,
  COUNT(DISTINCT rl.listing_id)                                          AS active_listings,
  COUNT(*)                                                               AS total_reviews,
  SUM(CASE WHEN rl.review_sentiment = 'positive' THEN 1 ELSE 0 END)     AS positive_reviews,
  SUM(CASE WHEN rl.review_sentiment = 'negative' THEN 1 ELSE 0 END)     AS negative_reviews,
  ROUND(
    100.0 * SUM(CASE WHEN rl.review_sentiment = 'positive' THEN 1 ELSE 0 END)
    / NULLIF(COUNT(*), 0), 1
  )                                                                      AS sentiment_score,
  ROUND(AVG(rl.price), 2)                                                AS avg_price,
  ROUND(COUNT(*) * AVG(rl.price), 2)                                     AS estimated_monthly_revenue
FROM review_listing rl
INNER JOIN hosts h ON rl.host_id = h.host_id
GROUP BY rl.host_id, h.is_superhost, rl.review_month
