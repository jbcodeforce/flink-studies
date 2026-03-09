CREATE TABLE IF NOT EXISTS cdc_marqeta_jcard_dbtransaction (
    record_content STRING
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
