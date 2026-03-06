

-- Package events stream: events sent in the morning per package.
-- event_ts must be before cutoff to count as "received".
CREATE TABLE package_events (
    package_id STRING,
    event_ts TIMESTAMP(3),
    status STRING,
    expected_ts TIMESTAMP(3),
    event_type STRING,
    payload STRING,
    WATERMARK FOR event_ts AS event_ts - INTERVAL '5' SECOND,
    primary key (package_id) not enforced
) with (
  'changelog.mode' = 'append',
  'value.avro-registry.schema-context' = '.flink-dev',
  'value.format' = 'avro-registry',
  'scan.startup.mode' = 'earliest-offset',
  'scan.bounded.mode' = 'unbounded',
  'value.fields-include' = 'all'
);
