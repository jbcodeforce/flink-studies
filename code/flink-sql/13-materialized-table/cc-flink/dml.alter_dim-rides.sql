CREATE OR ALTER MATERIALIZED TABLE dim_rides (
  driver_id STRING NOT NULL,
  total_rides BIGINT,
  total_distance DOUBLE,
  total_fare DOUBLE,
  car_type STRING,
  PRIMARY KEY(driver_id) NOT ENFORCED
)
  START_MODE = RESUME_OR_FROM_BEGINNING
 AS   SELECT
    coalesce(driver_id, 'Dummy') as driver_id,
    count(*) as total_rides,
    sum(distance) as total_distance,
    sum(fare) as total_fare,
    coalesce(car_type, 'S') as car_type
  FROM `raw_rides` group by driver_id, car_type;