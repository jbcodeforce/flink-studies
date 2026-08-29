-- After editing this query, you MUST run `dbt run --full-refresh` to deploy the change.
-- Schema-drift detection only checks columns, types, and WITH options — query logic
-- changes are not detected and will be silently skipped on a normal `dbt run`.
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
  CAST(SUBSTRING(updated_at, 1, 10) AS DATE)           AS snapshot_date,
  CASE
    WHEN price < 50                   THEN 'Budget'
    WHEN price >= 50  AND price < 150 THEN 'Mid-range'
    WHEN price >= 150 AND price < 300 THEN 'Premium'
    ELSE                                   'Luxury'
  END                                                  AS price_tier,
  CASE
    WHEN minimum_nights >= 1  AND minimum_nights <= 3  THEN 'Short'
    WHEN minimum_nights >= 4  AND minimum_nights <= 14 THEN 'Medium'
    WHEN minimum_nights >= 15 AND minimum_nights <= 30 THEN 'Long'
    ELSE                                                    'Extended'
  END                                                  AS min_stay_bucket
FROM listings
