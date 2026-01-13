-- -----------------------------------------------------------------------------
-- Delete Propagation Handling
-- Card Transaction Processing Demo
-- -----------------------------------------------------------------------------
-- Demonstrates how to handle DELETE operations from CDC
-- and propagate them to downstream sinks

-- Understanding Debezium DELETE handling in Flink:
-- 1. With 'after.state.only' = 'true', DELETEs appear as tombstone records (null value)
-- 2. Flink upsert-kafka connector handles this automatically
-- 3. For append-only sinks (S3/Iceberg), we need explicit delete markers

-- Create a table to track deletion events for audit purposes
CREATE TABLE IF NOT EXISTS deletion_audit (
    entity_type STRING,
    entity_id STRING,
    deleted_at TIMESTAMP_LTZ(3),
    operation STRING,
    -- Kafka metadata
    kafka_partition INT,
    kafka_offset BIGINT,
    PRIMARY KEY (entity_type, entity_id) NOT ENFORCED
) WITH (
    'connector' = 'upsert-kafka',
    'topic' = 'card-tx-deletion-audit',
    'properties.bootstrap.servers' = '${KAFKA_BOOTSTRAP_SERVERS}',
    'key.format' = 'avro-confluent',
    'key.avro-confluent.url' = '${SCHEMA_REGISTRY_URL}',
    'value.format' = 'avro-confluent',
    'value.avro-confluent.url' = '${SCHEMA_REGISTRY_URL}'
);

-- For S3/Iceberg sinks, create a changelog-style table
-- that includes the operation type (_op field)
CREATE TABLE IF NOT EXISTS transactions_changelog (
    txn_id STRING,
    account_number STRING,
    `timestamp` TIMESTAMP_LTZ(3),
    amount DECIMAL(10, 2),
    currency STRING,
    merchant STRING,
    location STRING,
    status STRING,
    transaction_type STRING,
    -- CDC operation type: INSERT, UPDATE, DELETE
    _op STRING,
    _event_time TIMESTAMP_LTZ(3),
    PRIMARY KEY (txn_id, _event_time) NOT ENFORCED
) WITH (
    'connector' = 'kafka',
    'topic' = 'card-tx-transactions-changelog',
    'properties.bootstrap.servers' = '${KAFKA_BOOTSTRAP_SERVERS}',
    'value.format' = 'avro-confluent',
    'value.avro-confluent.url' = '${SCHEMA_REGISTRY_URL}'
);

-- Capture all changes including deletes as changelog records
-- Note: This requires reading the full Debezium envelope, not 'after.state.only'
-- Configure CDC connector with 'after.state.only' = 'false' for this pattern

-- For proper delete propagation to Iceberg tables:
-- 1. Use TableFlow which handles deletes automatically via Iceberg's merge-on-read
-- 2. Or use the changelog pattern above with custom merge logic

-- Example: Merge logic for Iceberg in downstream processing (e.g., Spark/Flink batch)
-- MERGE INTO iceberg_transactions t
-- USING changelog_transactions c
-- ON t.txn_id = c.txn_id
-- WHEN MATCHED AND c._op = 'DELETE' THEN DELETE
-- WHEN MATCHED THEN UPDATE SET *
-- WHEN NOT MATCHED THEN INSERT *;
