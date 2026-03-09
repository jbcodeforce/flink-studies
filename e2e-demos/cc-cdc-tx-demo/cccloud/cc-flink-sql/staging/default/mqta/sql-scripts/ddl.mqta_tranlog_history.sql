CREATE TABLE IF NOT EXISTS cdc_marqeta_jcard_tranlog_history (
    record_content STRING,
    record_metadata STRING
) WITH (
     'changelog.mode' = 'append',
    'value.avro-registry.schema-context' = '.flink-dev',
    'value.format' = 'avro-registry',
    'kafka.retention.time' = '0',
    'kafka.producer.compression.type' = 'snappy',
    'scan.bounded.mode' = 'unbounded',
    'scan.startup.mode' = 'earliest-offset',
    'value.fields-include' = 'all'
);
