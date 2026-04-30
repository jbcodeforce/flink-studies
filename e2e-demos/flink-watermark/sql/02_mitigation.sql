-- Mitigation: mark idle sources after 5s of no data (global) and on the Kafka scan (per table).
-- Same SQL and topic as 01_baseline.sql; expect the [50s, 60s) window to appear in print output
-- without new events on idle partitions.

SET 'sql-client.execution.result-mode' = 'tableau';

SET 'parallelism.default' = '4';

SET 'table.exec.source.idle-timeout' = '5 s';

DROP TABLE IF EXISTS print_wm;
DROP TABLE IF EXISTS events;

CREATE TABLE events (
  event_id STRING,
  event_time TIMESTAMP_LTZ(3),
  WATERMARK FOR event_time AS event_time - INTERVAL '0' SECONDS
) WITH (
  'connector' = 'kafka',
  'topic' = 'watermark_demo',
  'properties.bootstrap.servers' = 'broker:29092',
  'properties.group.id' = 'flink-wm-mitigation',
  'scan.startup.mode' = 'earliest-offset',
  'scan.watermark.idle-timeout' = '5 s',
  'format' = 'json',
  'json.fail-on-missing-field' = 'false',
  'json.timestamp-format.standard' = 'ISO-8601'
);

CREATE TABLE print_wm (
  window_start TIMESTAMP_LTZ(3),
  window_end TIMESTAMP_LTZ(3),
  cnt BIGINT
) WITH (
  'connector' = 'print',
  'print-identifier' = 'wm-mitigation'
);

INSERT INTO print_wm
SELECT
  window_start,
  window_end,
  COUNT(*) AS cnt
FROM TABLE(
  TUMBLE(TABLE events, DESCRIPTOR(event_time), INTERVAL '10' SECONDS)
)
GROUP BY window_start, window_end;
