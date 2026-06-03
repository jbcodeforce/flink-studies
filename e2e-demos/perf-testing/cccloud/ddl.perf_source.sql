-- Confluent Cloud for Flink: Kafka source (perf-input).
-- Create topics perf-input / perf-output in CC before running.
-- Producer JSON schema: id, event_time, value, payload.

CREATE TABLE perf_source (
    id BIGINT,
    event_time STRING,
    value DOUBLE,
    payload STRING
) DISTRIBUTED BY HASH(id) INTO 1 BUCKETS WITH (
    'kafka.topic' = 'perf-input',
    'scan.startup.mode' = 'earliest-offset',
    'scan.bounded.mode' = 'unbounded',
    'value.format' = 'json',
    'value.fields-include' = 'all'
);
