CREATE TABLE IF NOT EXISTS `gcp_demo` (
    id INT,
    name STRING,
    PRIMARY KEY (id) NOT ENFORCED
) DISTRIBUTED BY HASH(id) INTO 1 BUCKETS WITH (
    'changelog.mode' = 'upsert',
    'key.format' = 'avro-registry',
    'value.format' = 'avro-registry',
    'value.fields-include' = 'all'
);
