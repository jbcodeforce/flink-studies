{{
  config(
    materialized = 'table'
  )
}}

WITH listings AS (
  SELECT
    listing_id,
    host_id,
    room_type,
    minimum_nights,
    price,
    updated_at
  FROM {{ ref('dim_listings_cleansed') }}
)

SELECT
  listing_id,
  host_id,
  room_type,
  minimum_nights,
  price,
  CAST(updated_at AS DATE)                          AS snapshot_date,
  CASE
    WHEN price < 50              THEN 'Budget'
    WHEN price BETWEEN 50 AND 149 THEN 'Mid-range'
    WHEN price BETWEEN 150 AND 299 THEN 'Premium'
    ELSE                             'Luxury'
  END                                               AS price_tier,
  CASE
    WHEN minimum_nights BETWEEN 1 AND 3   THEN 'Short'
    WHEN minimum_nights BETWEEN 4 AND 14  THEN 'Medium'
    WHEN minimum_nights BETWEEN 15 AND 30 THEN 'Long'
    ELSE                                      'Extended'
  END                                               AS min_stay_bucket
FROM listings
