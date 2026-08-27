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
  )
}}

WITH
l AS (
    SELECT
        *
    FROM
        {{ ref('dim_listings_cleansed') }}
),
h AS (
    SELECT *
    FROM {{ ref('dim_hosts_cleansed') }}
)

SELECT
    l.listing_id,
    l.listing_name,
    l.room_type,
    l.minimum_nights,
    l.price,
    l.host_id,
    h.host_name,
    h.is_superhost as host_is_superhost,
    l.created_at,
    GREATEST(l.updated_at, h.updated_at) as updated_at
FROM l
LEFT JOIN h ON (h.host_id = l.host_id)