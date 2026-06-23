CREATE TABLE d06_sensor_data (
    device_id int,
    ts timestamp_ltz(3),
    X int,
    Y int,
    val double,
    angle int,
    PRIMARY KEY(device_id,ts) NOT ENFORCED,
    WATERMARK FOR ts AS ts - INTERVAL '5' SECOND
) DISTRIBUTED BY (device_id, ts) INTO 1 BUCKETS
WITH (
    'changelog.mode' = 'append',
    'key.format' = 'avro-registry',
    'value.format' = 'avro-registry',
    'value.fields-include' = 'all',
    'scan.bounded.mode' = 'unbounded',
    'scan.startup.mode' = 'earliest-offset'
);