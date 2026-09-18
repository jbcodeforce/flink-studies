CREATE TABLE `dimension.latest_groups_users_rec` (
    group_uid STRING,
    group_member STRING,
    event_timestamp TIMESTAMP_LTZ(3),
    is_deleted BOOLEAN,
    PRIMARY KEY (group_uid, group_member) NOT ENFORCED
) DISTRIBUTED BY HASH (group_uid, group_member)  WITH 1 BUCKETS
WITH (
  'changelog.mode' = 'upsert',
  'connector' = 'confluent',
  'kafka.compaction.time' = '0 ms',
  'kafka.max-message-size' = '2097164 bytes',
  'scan.bounded.mode' = 'unbounded',
  'scan.startup.mode' = 'earliest-offset',
  'value.format' = 'avro-registry'
  'key.format' = 'avro-registry'
)