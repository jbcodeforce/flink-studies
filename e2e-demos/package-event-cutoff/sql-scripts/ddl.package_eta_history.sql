-- Use case 3: per-package ETA history (one row per package_id). Populated by dml.package_eta_history.sql; joined with package_events in dml.compute_eta.sql.
CREATE TABLE package_eta_history (
    package_id STRING,
    event_history ARRAY<ROW<event_ts TIMESTAMP(3), event_type STRING, current_location STRING, delivery_address STRING>>,
    ETA_2h_time_window_start TIMESTAMP(3),
    ETA_2h_time_window_end TIMESTAMP(3),
    ETA_day DATE,
    shipment_status STRING,
    previous_ETA_2h_time_window_start TIMESTAMP(3),
    previous_ETA_2h_time_window_end TIMESTAMP(3),
    risk_score DOUBLE,
    confidence DOUBLE,
    PRIMARY KEY (package_id) NOT ENFORCED
) WITH (
    'changelog.mode' = 'upsert',
    'key.avro-registry.schema-context' = '.flink-dev',
    'value.avro-registry.schema-context' = '.flink-dev',
    'key.format' = 'avro-registry',
    'value.format' = 'avro-registry',
    'kafka.retention.time' = '1',
    'kafka.producer.compression.type' = 'snappy',
    'scan.startup.mode' = 'earliest-offset',
    'scan.bounded.mode' = 'unbounded',
    'value.fields-include' = 'all'
);
