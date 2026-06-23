create table d06_locf_last_val (
    device_id int,
    max_last_X int,
    max_last_Y int,
    max_last_angle int,
    max_of_last_values double,
    PRIMARY KEY(device_id) NOT ENFORCED
) DISTRIBUTED BY (device_id) INTO 1 BUCKETS
WITH (
    'changelog.mode' = 'upsert',
    'key.format' = 'avro-registry',
    'value.format' = 'avro-registry',
    'value.fields-include' = 'all',
    'scan.bounded.mode' = 'unbounded',
    'scan.startup.mode' = 'earliest-offset'
);  