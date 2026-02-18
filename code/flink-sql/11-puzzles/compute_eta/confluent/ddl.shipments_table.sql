-- Confluent Cloud: shipment_events as Kafka-backed table (append-only stream).
-- Use with deploy_flink_statements.py --confluent-cloud.
CREATE TABLE IF NOT EXISTS shipment_events (
    shipment_id STRING,
    package_id STRING,
    event_ts TIMESTAMP(3),
    event_type STRING,
    current_location STRING,
    delivery_address STRING,
    WATERMARK FOR event_ts AS event_ts - INTERVAL '1' SECOND
) WITH (
    'changelog.mode' = 'append',
    'value.avro-registry.schema-context' = '.compute-eta',
    'value.format' = 'avro-registry',
    'scan.startup.mode' = 'earliest-offset',
    'value.fields-include' = 'all'
);
