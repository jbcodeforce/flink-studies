-- Apache Flink SQL (OSS) — local Kafka-backed source.
-- Runs on the Flink SQL client + broker from ../../docker-compose.yaml.
-- Unlike the cc-flink variant, OSS Flink needs an explicit connector.
--
-- 'scan.bounded.mode' = 'latest-offset' makes a SELECT read up to the latest
-- offset and then stop. On EOF a bounded source emits a final (MAX) watermark,
-- which flushes the last pending MATCH_RECOGNIZE match — so the demo terminates
-- with deterministic, complete output instead of hanging waiting for a watermark.
--
-- The broker auto-creates 'project_events' with its default 1 partition, so there
-- are no idle partitions to stall the watermark (the trap that returns ZERO rows
-- on a multi-partition Confluent Cloud topic — see cc-flink/ddl for the fix there).
CREATE TABLE project_events (
  project_id STRING,
  event_type STRING,   -- 'USER' or 'TASK'
  entity_id  STRING,   -- user id (U*) when USER, task id (T*) when TASK
  event_ts   TIMESTAMP(3),
  WATERMARK FOR event_ts AS event_ts - INTERVAL '1' SECOND
) WITH (
  'connector'                    = 'kafka',
  'topic'                        = 'project_events',
  'properties.bootstrap.servers' = 'broker:29092',
  'properties.group.id'          = 'flink-m2m',
  'scan.startup.mode'            = 'earliest-offset',
  'scan.bounded.mode'            = 'latest-offset',
  'format'                       = 'json'
);
