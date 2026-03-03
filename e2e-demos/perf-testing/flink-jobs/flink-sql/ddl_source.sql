-- Create Kafka source table for perf testing.
-- Replace placeholders before submitting: BOOTSTRAP_SERVERS, INPUT_TOPIC (default perf-input).

CREATE TABLE perf_source (
    id BIGINT,
    event_time STRING,
    value DOUBLE,
    payload STRING
) WITH (
    'connector' = 'kafka',
    'topic' = 'perf-input',
    'properties.bootstrap.servers' = '<BOOTSTRAP_SERVERS>',
    'scan.startup.mode' = 'earliest-offset',
    'format' = 'json'
);
