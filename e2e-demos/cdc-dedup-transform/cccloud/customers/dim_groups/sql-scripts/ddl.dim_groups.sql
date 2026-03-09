CREATE TABLE IF NOT EXISTS dim_groups (
  group_id string,
  group_name string,
  group_type string,
  created_date date,
  is_active boolean,
  description string,
  -- put here column definitions
  PRIMARY KEY(group_id) NOT ENFORCED
) DISTRIBUTED BY HASH(group_id) INTO 1 BUCKETS
WITH (
  'changelog.mode' = 'upsert',
  'key.avro-registry.schema-context' = '.flink-dev',
  'value.avro-registry.schema-context' = '.flink-dev',
  'key.format' = 'avro-registry',
  'value.format' = 'avro-registry',
  'kafka.retention.time' = '0',
  'kafka.producer.compression.type' = 'snappy',
  'scan.bounded.mode' = 'unbounded',
  'scan.startup.mode' = 'earliest-offset',
  'value.fields-include' = 'all'
);