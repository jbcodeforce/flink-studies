CREATE TABLE orders_with_currency_rates (
    order_id    STRING,
    price       DECIMAL(32,2),
    currency    STRING,
    order_time  TIMESTAMP_LTZ(3),
    conversion_rate DECIMAL(32,2),
    usd_converted_amount DECIMAL(32,2),
    WATERMARK FOR order_time AS order_time - INTERVAL '15' SECOND
) WITH (
    'changelog.mode' = 'append',
    'value.format' = 'avro-registry',
    'value.fields-include' = 'all',
    'value.json-registry.schema-context' = '.flink-dev',
    'scan.startup.mode' = 'earliest-offset',
    'scan.bounded.mode' = 'unbounded'
);