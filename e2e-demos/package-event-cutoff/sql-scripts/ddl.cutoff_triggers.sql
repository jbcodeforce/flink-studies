
-- Cutoff trigger: one record per cutoff time (e.g. 11:30).
CREATE TABLE cutoff_triggers (
    cutoff_ts TIMESTAMP(3),
    WATERMARK FOR cutoff_ts AS cutoff_ts - INTERVAL '5' SECOND
) WITH (
  'changelog.mode' = 'append',
  'value.avro-registry.schema-context' = '.flink-dev',
  'value.format' = 'avro-registry',
  'scan.startup.mode' = 'earliest-offset',
  'scan.bounded.mode' = 'unbounded',
  'value.fields-include' = 'all'
);
