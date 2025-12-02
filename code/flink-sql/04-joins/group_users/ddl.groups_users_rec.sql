CREATE TABLE `groups_users_rec` (
    group_uid STRING,
    group_member STRING,
    event_timestamp TIMESTAMP_LTZ(3),
    is_deleted BOOLEAN,
    PRIMARY KEY (group_uid, group_member) NOT ENFORCED
)
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