-- Append-only generic event envelope (topic: event_stream).
-- context_data carries eventType; event_details is a JSON array of payload objects.
-- Retention: 6 days (Kafka topic + Flink join state TTL on stream aliases).
CREATE TABLE IF NOT EXISTS event_stream (
    event_id STRING,
    event_time TIMESTAMP_LTZ(3),
    context_data STRING,
    event_details ARRAY<STRING>,
    WATERMARK FOR event_time AS event_time - INTERVAL '5' SECOND
) DISTRIBUTED BY (event_id) INTO 4 BUCKETS
WITH (
    'changelog.mode' = 'append',
    'key.format' = 'avro-registry',
    'value.format' = 'avro-registry'
);
