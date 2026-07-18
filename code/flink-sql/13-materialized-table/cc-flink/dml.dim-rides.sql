CREATE MATERIALIZED TABLE dim_rides (
  driver_id STRING NOT NULL,
  total_rides BIGINT,
  total_distance DOUBLE,
  total_fare DOUBLE,
  PRIMARY KEY(driver_id) NOT ENFORCED
)
  DISTRIBUTED BY (driver_id)
 WITH (
     'changelog.mode' = 'upsert',
      'key.format' = 'avro-registry',
      'value.format' = 'avro-registry',
      'value.fields-include' = 'all'
 )
  FRESHNESS = INTERVAL '1' MINUTE
 AS   SELECT
    coalesce(driver_id, 'Dummy') as driver_id,
    count(*) as total_rides,
    sum(distance) as total_distance,
    sum(fare) as total_fare
  FROM `raw_rides` group by driver_id;