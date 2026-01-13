-- -----------------------------------------------------------------------------
-- Multi-level Deduplication Pattern
-- Card Transaction Processing Demo
-- -----------------------------------------------------------------------------
-- Demonstrates how to handle duplicate CDC records using multi-level deduplication
-- Useful for handling CDC replay scenarios and ensuring idempotency
--
-- Strategy:
-- 1. First-level deduplication by transaction ID and position (if available)
-- 2. Second-level deduplication by source timestamp
-- 3. Handle cases where the same record appears multiple times in CDC streams

-- Step 1: Create a staging table with metadata for deduplication
-- This table includes all CDC metadata needed for deduplication logic

CREATE TABLE IF NOT EXISTS customers_staging (
    account_number STRING,
    customer_name STRING,
    email STRING,
    phone_number STRING,
    city STRING,
    created_at STRING,
    
    -- CDC metadata for deduplication
    cdc_operation STRING,
    source_timestamp_ms BIGINT,
    source_timestamp TIMESTAMP_LTZ(3),
    
    -- Transaction metadata (if available)
    -- Note: These may not be available in all Debezium configurations
    -- transaction_id STRING,
    -- transaction_order INT,
    -- data_collection_order INT,
    
    -- Kafka metadata for deduplication
    kafka_partition INT,
    kafka_offset BIGINT,
    
    -- Source information
    source_database STRING,
    source_table STRING,
    is_snapshot STRING
) WITH (
    'connector' = 'kafka',
    'topic' = 'card-tx-customers-staging',
    'properties.bootstrap.servers' = '${KAFKA_BOOTSTRAP_SERVERS}',
    'value.format' = 'avro-confluent',
    'value.avro-confluent.url' = '${SCHEMA_REGISTRY_URL}',
    'scan.startup.mode' = 'earliest-offset'
);

-- Step 2: Populate staging table with metadata
-- Extract data from Debezium envelope with all metadata

INSERT INTO customers_staging
SELECT 
    COALESCE(IF(op = 'd', before.account_number, after.account_number), '') AS account_number,
    COALESCE(IF(op = 'd', before.customer_name, after.customer_name), 'NULL') AS customer_name,
    COALESCE(IF(op = 'd', before.email, after.email), 'NULL') AS email,
    COALESCE(IF(op = 'd', before.phone_number, after.phone_number), 'NULL') AS phone_number,
    COALESCE(IF(op = 'd', before.city, after.city), 'NULL') AS city,
    COALESCE(IF(op = 'd', before.created_at, after.created_at), 'NULL') AS created_at,
    op AS cdc_operation,
    source.ts_ms AS source_timestamp_ms,
    TO_TIMESTAMP_LTZ(source.ts_ms, 3) AS source_timestamp,
    -- Kafka metadata (requires METADATA columns in source table definition)
    -- `partition` AS kafka_partition,
    -- `offset` AS kafka_offset,
    0 AS kafka_partition,  -- Placeholder - should be extracted from metadata
    0 AS kafka_offset,     -- Placeholder - should be extracted from metadata
    source.db AS source_database,
    source.table AS source_table,
    COALESCE(CAST(source.snapshot AS STRING), 'false') AS is_snapshot
FROM `card-tx.public.customers`
WHERE source.ts_ms IS NOT NULL;

-- Step 3: Multi-level deduplication using window functions
-- First deduplication: By account_number and source timestamp
-- This handles cases where the same record appears multiple times

CREATE TABLE IF NOT EXISTS customers_deduplicated (
    account_number STRING,
    customer_name STRING,
    email STRING,
    phone_number STRING,
    city STRING,
    created_at STRING,
    cdc_operation STRING,
    source_timestamp TIMESTAMP_LTZ(3),
    source_database STRING,
    source_table STRING,
    is_snapshot STRING,
    -- Deduplication metadata
    deduplication_rank INT,
    PRIMARY KEY (account_number, source_timestamp) NOT ENFORCED
) WITH (
    'connector' = 'upsert-kafka',
    'topic' = 'card-tx-customers-deduplicated',
    'properties.bootstrap.servers' = '${KAFKA_BOOTSTRAP_SERVERS}',
    'key.format' = 'avro-confluent',
    'key.avro-confluent.url' = '${SCHEMA_REGISTRY_URL}',
    'value.format' = 'avro-confluent',
    'value.avro-confluent.url' = '${SCHEMA_REGISTRY_URL}'
);

-- Deduplication query using ROW_NUMBER() window function
-- This pattern ensures only the latest record (by source timestamp) is kept
-- for each account_number

INSERT INTO customers_deduplicated
SELECT 
    account_number,
    customer_name,
    email,
    phone_number,
    city,
    created_at,
    cdc_operation,
    source_timestamp,
    source_database,
    source_table,
    is_snapshot,
    deduplication_rank
FROM (
    SELECT 
        account_number,
        customer_name,
        email,
        phone_number,
        city,
        created_at,
        cdc_operation,
        source_timestamp,
        source_database,
        source_table,
        is_snapshot,
        -- First-level deduplication: Rank by source timestamp (most recent first)
        ROW_NUMBER() OVER (
            PARTITION BY account_number
            ORDER BY source_timestamp DESC, kafka_offset DESC
        ) AS deduplication_rank
    FROM customers_staging
    WHERE account_number IS NOT NULL AND account_number != ''
)
WHERE deduplication_rank = 1;

-- Alternative: Two-level deduplication pattern
-- If transaction metadata is available, use it for first-level deduplication
-- Then use timestamp for second-level deduplication

-- WITH ranked_by_transaction AS (
--     SELECT *,
--         ROW_NUMBER() OVER (
--             PARTITION BY account_number, transaction_id
--             ORDER BY transaction_order DESC, data_collection_order DESC
--         ) AS tx_rank
--     FROM customers_staging
--     WHERE transaction_id IS NOT NULL
-- ),
-- ranked_by_timestamp AS (
--     SELECT *,
--         ROW_NUMBER() OVER (
--             PARTITION BY account_number
--             ORDER BY source_timestamp DESC
--         ) AS ts_rank
--     FROM ranked_by_transaction
--     WHERE tx_rank = 1
-- )
-- SELECT * FROM ranked_by_timestamp WHERE ts_rank = 1;

-- Use case: Handle CDC replay scenarios
-- When replaying CDC events, the same record may appear multiple times
-- This deduplication ensures idempotency

-- Use case: Handle out-of-order CDC events
-- If events arrive out of order, the timestamp-based ranking ensures
-- the most recent state is preserved

-- Best practices:
-- 1. Always include source_timestamp in deduplication logic
-- 2. Use Kafka offset as tie-breaker when timestamps are identical
-- 3. Consider transaction boundaries if available
-- 4. For upsert sinks, the primary key handles some deduplication automatically
-- 5. For append-only sinks, explicit deduplication is required
