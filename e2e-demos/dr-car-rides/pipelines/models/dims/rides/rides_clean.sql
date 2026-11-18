{{ config(
    materialized='streaming_table',
    statement_name='dr-dims-rides-clean',
    distributed_by={
        'columns': ['driver_id'],
        'buckets': 6
    },
    with={
        'changelog.mode': 'append',
        'key.format': 'json-registry',
        'value.format': 'json-registry',
        'value.fields-include': 'all',
        'kafka.cleanup-policy': 'compact',
        'kafka.retention.time': '86400000 ms',
        'scan.bounded.mode': 'unbounded',
        'scan.startup.mode': 'earliest-offset'
    }
) }}

-- Migrated from dml.rides_clean.sql
-- Stage 1: stateless filter + city normalize → rides_clean
-- On DR failover, restart with earliest-offset (see the failover runbook in README.md)
-- rides_raw is owned by Terraform; its pickup_ts is epoch millis (BIGINT), converted
-- here to the TIMESTAMP(3) event-time column declared in schema.yml.
SELECT
    driver_id,
    ride_id,
    seq,
    rider_id,
    CAST(TO_TIMESTAMP_LTZ(pickup_ts, 3) AS TIMESTAMP(3)) AS pickup_ts,
    fare_usd,
    status,
    UPPER(TRIM(city)) AS city
FROM {{ source('rides', 'rides_raw') }}
WHERE status IN ('completed', 'cancelled')
