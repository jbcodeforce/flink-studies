-- Error sink table for provider transformation errors
CREATE TABLE provider_error_sink (
    error_timestamp TIMESTAMP(3),
    error_message STRING,
    provider_id STRING,
    raw_data STRING,
    error_type STRING,
    PRIMARY KEY (error_timestamp, provider_id) NOT ENFORCED
) WITH (
    'connector' = 'upsert-kafka',
    'topic' = 'provider_transform_errors',
    'properties.bootstrap.servers' = 'localhost:9092',
    'key.format' = 'json',
    'value.format' = 'json'
);
