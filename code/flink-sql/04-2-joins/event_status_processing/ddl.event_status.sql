 group_uid STRING,
    eventId STRING,
    eventProcessed BOOLEAN,
    event_timestamp TIMESTAMP_LTZ(3),
    PRIMARY KEY (eventId) NOT ENFORCED
) DISTRIBUTED BY HASH (eventId)  WITH 1 BUCKETS
WITH (
  'changelog.mode' = 'append',
  'connector' = 'confluent',
  'kafka.compaction.time' = '0 ms',
  'kafka.max-message-size' = '2097164 bytes',
  'scan.bounded.mode' = 'unbounded',
  'scan.startup.mode' = 'earliest-offset',
  'value.format' = 'avro-registry'
  'key.format' = 'avro-registry'
)