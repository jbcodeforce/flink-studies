CREATE TABLE IF NOT EXISTS shipment_events (
    shipment_id STRING,
    package_id STRING,
    event_ts TIMESTAMP(3),
    event_type STRING,
    current_location STRING,
    delivery_address STRING,
    WATERMARK FOR event_ts AS event_ts - INTERVAL '1' SECOND
) WITH (
    'connector' = 'filesystem',
    'path' = 'data/shipment_events.json',
    'format' = 'json',
    'json.timestamp-format.standard' = 'ISO-8601'
);
