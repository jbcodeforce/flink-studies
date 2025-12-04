CREATE TABLE orders (
    order_id    STRING,
    price       DECIMAL(32,2),
    currency    STRING,
    order_time  TIMESTAMP_LTZ(3),
    WATERMARK FOR order_time AS order_time - INTERVAL '15' SECOND,
    PRIMARY KEY (order_id) NOT ENFORCED
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