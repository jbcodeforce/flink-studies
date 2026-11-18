{{ config(
    materialized='streaming_table',
    statement_name='dr-facts-driver-stats',
    distributed_by={
        'columns': ['driver_id'],
        'buckets': 6
    },
    with={
        'key.format': 'json-registry',
        'value.format': 'json-registry',
        'value.fields-include': 'all',
        'changelog.mode': 'append',
        'scan.bounded.mode': 'unbounded',
        'scan.startup.mode': 'earliest-offset',
        'kafka.retention.time': '86400000 ms'
    }
) }}

-- Migrated from dml.driver_stats.sql
-- Stage 2: event-time tumble by driver → driver_stats
SELECT
    driver_id,
    window_start,
    window_end,
    COUNT(*) AS ride_count,
    SUM(fare_usd) AS fare_sum,
    MAX(seq) AS max_seq
FROM TABLE(
    TUMBLE(TABLE {{ ref('rides_clean') }}, DESCRIPTOR(pickup_ts), INTERVAL '1' MINUTE)
)
GROUP BY driver_id, window_start, window_end
