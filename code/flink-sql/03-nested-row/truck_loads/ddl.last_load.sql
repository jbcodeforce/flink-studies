create table last_load(
    truck_id STRING,
    good_id STRING,
    ts_ms BIGINT,
    PRIMARY KEY(truck_id) NOT ENFORCED
) DISTRIBUTED INTO 1 BUCKETS
WITH (
  'changelog.mode' = 'upsert',
  'connector' = 'confluent',
  'kafka.cleanup-policy' = 'delete',
    'key.format' = 'avro-registry',
  'value.format' = 'avro-registry',
  'value.fields-include' = 'all'
);