CREATE TABLE truck_loads (
        truck_id STRING,
        loads ARRAY<ROW<c_id INT ,good_id STRING, ts_ms BIGINT>>
    )
    DISTRIBUTED INTO 6 BUCKETS
WITH (
  'changelog.mode' = 'append',
  'connector' = 'confluent',
  'kafka.cleanup-policy' = 'delete',
  'scan.bounded.mode' = 'unbounded',
  'scan.startup.mode' = 'earliest-offset',
  'value.format' = 'avro-registry'
);

