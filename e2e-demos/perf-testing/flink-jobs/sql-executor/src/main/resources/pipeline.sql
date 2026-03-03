-- Source: Kafka topic (same schema as producer output)
-- Placeholders: ${BOOTSTRAP_SERVERS}, ${INPUT_TOPIC}, ${OUTPUT_TOPIC}

CREATE TABLE perf_source (
    id BIGINT,
    event_time STRING,
    value DOUBLE,
    payload STRING
) WITH (
    'connector' = 'kafka',
    'topic' = '${INPUT_TOPIC}',
    'properties.bootstrap.servers' = '${BOOTSTRAP_SERVERS}',
    'scan.startup.mode' = 'earliest-offset',
    'format' = 'json'
);

CREATE TABLE perf_sink (
    id BIGINT,
    event_time STRING,
    value DOUBLE,
    payload STRING
) WITH (
    'connector' = 'kafka',
    'topic' = '${OUTPUT_TOPIC}',
    'properties.bootstrap.servers' = '${BOOTSTRAP_SERVERS}',
    'format' = 'json'
);

INSERT INTO perf_sink SELECT id, event_time, value, payload FROM perf_source;
