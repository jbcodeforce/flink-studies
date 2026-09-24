CREATE MATERIALIZED TABLE dim_car_rides (
  driver_id    STRING NOT NULL,
  window_start TIMESTAMP_LTZ(3) NOT NULL,
  window_end   TIMESTAMP_LTZ(3) NOT NULL,
  total_rides  BIGINT,
  total_distance DOUBLE,
  total_fare   DOUBLE,
  PRIMARY KEY(driver_id, window_start, window_end) NOT ENFORCED
)
  DISTRIBUTED BY (driver_id,  window_start, window_end)
  WITH (
    'changelog.mode'       = 'upsert',
    'key.format'           = 'avro-registry',
    'value.format'         = 'avro-registry',
    'value.fields-include' = 'all'
  )
  FRESHNESS = INTERVAL '1' MINUTE
AS
  SELECT
    coalesce(driver_id, 'Dummy') AS driver_id,
    window_start,
    window_end,
    count(*)      AS total_rides,
    sum(distance) AS total_distance,
    sum(fare)     AS total_fare
  FROM TABLE(
    TUMBLE(TABLE mt_raw_rides, DESCRIPTOR(pickup_ts), INTERVAL '30' MINUTES)
  )
  GROUP BY driver_id, window_start, window_end;
