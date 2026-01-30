-- Historical table: one row per shipment_id with array of event info and ETA fields for ETA computation.
-- Populated by dml.shipment_history.sql; joined with shipment_events in dml.compute_eta.sql.
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
) WITH (
    'connector' = 'filesystem',
    'path' = 'data/shipment_history',
    'format' = 'json',
    'json.timestamp-format.standard' = 'ISO-8601'
);
