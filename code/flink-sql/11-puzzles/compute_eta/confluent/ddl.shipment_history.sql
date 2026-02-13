-- Confluent Cloud: shipment_history as Kafka-backed table (upsert by shipment_id).
-- Use with deploy_flink_statements.py --confluent-cloud.
CREATE TABLE IF NOT EXISTS shipment_history (
    shipment_id STRING,
    event_history ARRAY<ROW<event_ts TIMESTAMP(3), event_type STRING, current_location STRING, delivery_address STRING>>,
    ETA_2h_time_window_start TIMESTAMP(3),
    ETA_2h_time_window_end TIMESTAMP(3),
    ETA_day DATE,
    shipment_status STRING,
    previous_ETA_2h_time_window_start TIMESTAMP(3),
    previous_ETA_2h_time_window_end TIMESTAMP(3),
    risk_score DOUBLE,
    confidence DOUBLE,
    PRIMARY KEY (shipment_id) NOT ENFORCED
) DISTRIBUTED BY HASH(shipment_id) INTO 1 BUCKETS
WITH (
    'changelog.mode' = 'upsert',
    'key.avro-registry.schema-context' = '.compute-eta',
    'value.avro-registry.schema-context' = '.compute-eta',
    'key.format' = 'avro-registry',
    'value.format' = 'avro-registry',
    'kafka.retention.time' = '0',
    'kafka.producer.compression.type' = 'snappy',
    'scan.bounded.mode' = 'unbounded',
    'scan.startup.mode' = 'earliest-offset',
    'value.fields-include' = 'all'
);
