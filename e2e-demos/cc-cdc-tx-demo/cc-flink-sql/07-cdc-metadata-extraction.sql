-- -----------------------------------------------------------------------------
-- CDC Metadata Extraction
-- Card Transaction Processing Demo
-- -----------------------------------------------------------------------------
-- Comprehensive example showing how to extract all CDC metadata from Debezium envelopes
-- This demonstrates best practices for audit trails and debugging CDC pipelines
--
-- Metadata includes:
-- - Source timestamps (source.ts_ms)
-- - Transaction metadata (transaction.id, transaction.total_order, transaction.data_collection_order)
-- - Kafka metadata (partition, offset, key)
-- - Source information (database, table, schema, server name)
-- - Snapshot flags
-- - Operation type and timestamps

-- Example: Extract comprehensive CDC metadata from customers table
-- Note: This assumes the table is configured with 'value.format' = 'avro-registry'
-- to access the full Debezium envelope (before, after, source, op)

SELECT 
    -- Business fields (extracted from before/after based on operation)
    COALESCE(
        IF(op = 'd', before.account_number, after.account_number),
        IF(op = 'd', before.account_number, after.account_number)
    ) AS account_number,
    COALESCE(
        IF(op = 'd', before.customer_name, after.customer_name),
        'NULL'
    ) AS customer_name,
    COALESCE(
        IF(op = 'd', before.email, after.email),
        'NULL'
    ) AS email,
    COALESCE(
        IF(op = 'd', before.phone_number, after.phone_number),
        'NULL'
    ) AS phone_number,
    COALESCE(
        IF(op = 'd', before.city, after.city),
        'NULL'
    ) AS city,
    
    -- CDC operation metadata
    op AS cdc_operation,
    -- Source timestamp (milliseconds since epoch)
    source.ts_ms AS source_timestamp_ms,
    -- Source timestamp as proper timestamp type
    TO_TIMESTAMP_LTZ(source.ts_ms, 3) AS source_timestamp,
    
    -- Transaction metadata (if available in Debezium)
    -- Note: These fields may not be available in all Debezium configurations
    -- transaction.id AS transaction_id,
    -- transaction.total_order AS transaction_order,
    -- transaction.data_collection_order AS data_collection_order,
    
    -- Kafka metadata (extracted from Kafka connector metadata)
    -- Note: These require METADATA columns in table definition or can be accessed via connector
    -- `partition` AS kafka_partition,
    -- `offset` AS kafka_offset,
    -- `key` AS kafka_key,
    
    -- Source information
    source.db AS source_database,
    source.table AS source_table,
    source.schema AS source_schema,
    source.name AS source_connector_name,
    source.version AS source_connector_version,
    
    -- Snapshot flag - distinguishes initial load vs. incremental changes
    COALESCE(CAST(source.snapshot AS STRING), 'false') AS is_snapshot,
    
    -- Additional source metadata
    source.lsn AS source_lsn,  -- PostgreSQL log sequence number
    source.txId AS source_transaction_id,  -- PostgreSQL transaction ID
    
    -- Processing metadata
    CURRENT_TIMESTAMP AS processed_at,
    
    -- Deleted flag for easier filtering
    (op = 'd') AS is_deleted
    
FROM `card-tx.public.customers`
WHERE source.ts_ms IS NOT NULL;

-- Example: Create a table with comprehensive CDC metadata
-- This table can be used for audit trails, debugging, and data lineage tracking

CREATE TABLE IF NOT EXISTS customers_with_metadata (
    -- Business fields
    account_number STRING,
    customer_name STRING,
    email STRING,
    phone_number STRING,
    city STRING,
    
    -- CDC operation metadata
    cdc_operation STRING,
    source_timestamp_ms BIGINT,
    source_timestamp TIMESTAMP_LTZ(3),
    
    -- Source information
    source_database STRING,
    source_table STRING,
    source_schema STRING,
    source_connector_name STRING,
    source_connector_version STRING,
    
    -- Snapshot and processing flags
    is_snapshot STRING,
    is_deleted BOOLEAN,
    processed_at TIMESTAMP_LTZ(3),
    
    -- Primary key
    PRIMARY KEY (account_number, source_timestamp) NOT ENFORCED
) WITH (
    'connector' = 'upsert-kafka',
    'topic' = 'card-tx-customers-metadata',
    'properties.bootstrap.servers' = '${KAFKA_BOOTSTRAP_SERVERS}',
    'key.format' = 'avro-confluent',
    'key.avro-confluent.url' = '${SCHEMA_REGISTRY_URL}',
    'value.format' = 'avro-confluent',
    'value.avro-confluent.url' = '${SCHEMA_REGISTRY_URL}'
);

-- Insert enriched data with metadata
INSERT INTO customers_with_metadata
SELECT 
    COALESCE(
        IF(op = 'd', before.account_number, after.account_number),
        IF(op = 'd', before.account_number, after.account_number)
    ) AS account_number,
    COALESCE(IF(op = 'd', before.customer_name, after.customer_name), 'NULL') AS customer_name,
    COALESCE(IF(op = 'd', before.email, after.email), 'NULL') AS email,
    COALESCE(IF(op = 'd', before.phone_number, after.phone_number), 'NULL') AS phone_number,
    COALESCE(IF(op = 'd', before.city, after.city), 'NULL') AS city,
    op AS cdc_operation,
    source.ts_ms AS source_timestamp_ms,
    TO_TIMESTAMP_LTZ(source.ts_ms, 3) AS source_timestamp,
    source.db AS source_database,
    source.table AS source_table,
    source.schema AS source_schema,
    source.name AS source_connector_name,
    source.version AS source_connector_version,
    COALESCE(CAST(source.snapshot AS STRING), 'false') AS is_snapshot,
    (op = 'd') AS is_deleted,
    CURRENT_TIMESTAMP AS processed_at
FROM `card-tx.public.customers`
WHERE source.ts_ms IS NOT NULL;

-- Use case: Query to identify records from initial snapshot vs. incremental changes
-- SELECT 
--     account_number,
--     customer_name,
--     is_snapshot,
--     cdc_operation,
--     source_timestamp
-- FROM customers_with_metadata
-- WHERE is_snapshot = 'true'
-- ORDER BY source_timestamp;

-- Use case: Track all changes to a specific customer for audit purposes
-- SELECT 
--     account_number,
--     customer_name,
--     cdc_operation,
--     source_timestamp,
--     source_database,
--     source_table,
--     processed_at
-- FROM customers_with_metadata
-- WHERE account_number = 'ACC000001'
-- ORDER BY source_timestamp DESC;
