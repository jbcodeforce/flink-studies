{{ config(
    materialized = 'streaming_table',
    with= {
        'changelog.mode': 'append',
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
    )
}}

WITH src_listings AS (
  SELECT
    *
  FROM
    {{ ref('src_listings') }}
)
SELECT
  listing_id,
  listing_name,
  room_type,
  CASE
    WHEN minimum_nights = 0 THEN 1
    ELSE minimum_nights
  END AS minimum_nights,
  host_id,
  CAST(
    REPLACE(price_str, '$', '') AS DECIMAL(10, 2)
  ) AS price,
  created_at,
  updated_at
FROM
  src_listings