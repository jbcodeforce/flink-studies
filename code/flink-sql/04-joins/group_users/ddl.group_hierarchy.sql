CREATE TABLE group_hierarchy (
    id              INT PRIMARY KEY NOT ENFORCED,
    group_name   STRING,
    item_name    STRING,
    item_type    STRING NOT NULL,   -- 'GROUP' or 'PERSON'
    created_at   TIMESTAMP_LTZ(3)
) DISTRIBUTED BY HASH(id) INTO 1 BUCKETS
WITH (
  'changelog.mode' = 'append',
  'connector' = 'confluent',
  'kafka.compaction.time' = '0 ms',
  'kafka.max-message-size' = '2097164 bytes',
  'scan.bounded.mode' = 'unbounded',
  'scan.startup.mode' = 'earliest-offset',
   'value.fields-include' = 'all',
  'value.format' = 'avro-registry'
)