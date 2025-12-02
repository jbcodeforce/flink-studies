CREATE TABLE currency_rates (
    currency STRING,
    conversion_rate DECIMAL(32, 2),
    update_time TIMESTAMP_LTZ(3),
    WATERMARK FOR update_time AS update_time - INTERVAL '15' SECOND,
    PRIMARY KEY (currency) NOT ENFORCED
) WITH (
    'changelog.mode' = 'append',
    'value.format' = 'avro-registry',
    'key.format' = 'avro-registry',
    'value.fields-include' = 'all',
    'value.json-registry.schema-context' = '.flink-dev',
    'key.json-registry.schema-context' = '.flink-dev',
    'scan.startup.mode' = 'earliest-offset',
    'scan.bounded.mode' = 'unbounded'
);