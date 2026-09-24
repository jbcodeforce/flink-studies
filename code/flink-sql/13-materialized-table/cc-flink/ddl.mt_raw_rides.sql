-- As we suppose we cannot touch raw_rides source topic, we want
-- to set a watermark to pickup_time, so it has to be a TIMESTAMP_LTZ and
-- not a epoch-milliseconds (BIGINT).
CREATE MATERIALIZED TABLE mt_raw_rides (
    ride_id        STRING,
    driver_id      STRING,
    pickup_location  STRING,
    dropoff_location STRING,
    distance       DOUBLE,
    fare           DOUBLE,
    payment_type   STRING,
    rating         DOUBLE,
    pickup_ts  TO_TIMESTAMP_LTZ(3),
    dropoff_ts TO_TIMESTAMP_LTZ(3),
    PRIMARY KEY(ride_id) NOT ENFORCED,
    WATERMARK FOR pickup_ts AS pickup_ts - INTERVAL '5' MINUTES
) DISTRIBUTED BY (ride_id) INTO '1' BUCKETS
    WITH (
        'changelog.mode' = 'append',
        'value.format'   = 'json-registry',
        'key.format'     = 'json-registry',
        'value.fields-include' = 'all'
    )
   FRESHNESS = INTERVAL '1' MINUTE
AS
    SELECT
        ride_id,
        driver_id,
        pickup_location,
        dropoff_location,
        distance,
        fare,
        payment_type,
        rating,
        TO_TIMESTAMP_LTZ(pickup_time, 3) AS pickup_ts,
        TO_TIMESTAMP_LTZ(dropoff_time, 3) AS dropoff_ts
    FROM raw_rides
    WHERE ride_id IS NOT NULL