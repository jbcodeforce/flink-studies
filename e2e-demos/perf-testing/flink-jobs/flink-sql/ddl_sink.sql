-- Create Kafka sink table for perf testing.
-- Replace placeholders before submitting: BOOTSTRAP_SERVERS, OUTPUT_TOPIC (default perf-output).

CREATE TABLE perf_sink (
    id BIGINT,
    event_time STRING,
    value DOUBLE,
    payload STRING
) WITH (
    'connector' = 'kafka',
    'topic' = 'perf-output',
    'properties.bootstrap.servers' = '<BOOTSTRAP_SERVERS>',
    'format' = 'json'
);
