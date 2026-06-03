-- Confluent Cloud for Flink: Kafka sink (perf-output).

CREATE TABLE perf_sink (
    id BIGINT,
    event_time STRING,
    value DOUBLE,
    payload STRING
) DISTRIBUTED BY HASH(id) INTO 1 BUCKETS WITH (
    'kafka.topic' = 'perf-output',
    'value.format' = 'json',
    'value.fields-include' = 'all'
);
