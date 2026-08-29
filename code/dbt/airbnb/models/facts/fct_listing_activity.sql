{{
  config(
    materialized = 'table'
  )
}}

WITH review_agg AS (
  SELECT
    listing_id,
    MIN(review_date)                                   AS first_review_date,
    MAX(review_date)                                   AS last_review_date,
    COUNT(*)                                           AS total_reviews
  FROM {{ ref('fct_reviews') }}
  GROUP BY listing_id
),

listings AS (
  SELECT
    listing_id,
    host_id,
    room_type,
    price
  FROM {{ ref('dim_listings_cleansed') }}
)

SELECT
  l.listing_id,
  l.host_id,
  l.room_type,
  l.price,
  r.first_review_date,
  r.last_review_date,
  r.total_reviews,
  DATEDIFF('day', r.first_review_date, r.last_review_date)        AS days_active,
  ROUND(
    CAST(DATEDIFF('day', r.first_review_date, r.last_review_date) AS DOUBLE)
    / NULLIF(r.total_reviews - 1, 0), 1
  )                                                                AS avg_days_between_reviews,
  DATEDIFF('day', r.last_review_date, CURRENT_DATE)               AS days_since_last_review,
  CASE
    WHEN r.total_reviews <= 3                                       THEN 'New'
    WHEN DATEDIFF('day', r.last_review_date, CURRENT_DATE) <= 180  THEN 'Active'
    ELSE                                                                 'Dormant'
  END                                                              AS activity_status
FROM listings l
INNER JOIN review_agg r ON l.listing_id = r.listing_id
