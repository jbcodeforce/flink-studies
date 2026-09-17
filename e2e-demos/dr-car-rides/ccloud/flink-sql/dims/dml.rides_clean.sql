-- Stage 1: stateless filter + city normalize → rides_clean
-- On DR failover, restart with earliest-offset (see DR runbook in ccloud/README.md)
INSERT INTO rides_clean
SELECT
    driver_id,
    ride_id,
    seq,
    rider_id,
    pickup_ts,
    fare_usd,
    status,
    UPPER(TRIM(city)) AS city
FROM rides_raw
WHERE status IN ('completed', 'cancelled');
