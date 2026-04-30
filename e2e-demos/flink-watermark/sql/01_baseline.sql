-- Baseline: no global source idle handling (0) and no per-connector scan idle on the Kafka table.
-- Expect: windows that need event time past the idle partitions' last times do not complete
-- (the runbook targets the [50s, 60s) window on real event time from the producer).

SET 'sql-client.execution.result-mode' = 'tableau';

SET 'parallelism.default' = '4';

SET 'table.exec.source.idle-timeout' = '0 ms';

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
  'properties.group.id' = 'flink-wm-baseline',
  'scan.startup.mode' = 'earliest-offset',
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
  'print-identifier' = 'wm-baseline'
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
