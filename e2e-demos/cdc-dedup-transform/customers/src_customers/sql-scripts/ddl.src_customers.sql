CREATE TABLE IF NOT EXISTS src_customers (
    customer_id string,
    rec_pk_hash string,
    name string,
    email string,
    age int,
    rec_created_ts timestamp_ltz,
    rec_updated_ts timestamp_ltz,
    rec_crud_text string,
    hdr_changeSequence string,
    hdr_timestamp timestamp_ltz,
    primary key(customer_id) not enforced
) distributed by hash(customer_id) into 1 buckets 
WITH (
  'changelog.mode' = 'upsert',
  'key.avro-registry.schema-context' = '.flink-dev',
  'value.avro-registry.schema-context' = '.flink-dev',
  'key.format' = 'avro-registry',
  'value.format' = 'avro-registry',
  'kafka.retention.time' = '0',
  'kafka.producer.compression.type' = 'snappy',
  'scan.bounded.mode' = 'unbounded',
  'scan.startup.mode' = 'earliest-offset',
  'value.fields-include' = 'all'
);
