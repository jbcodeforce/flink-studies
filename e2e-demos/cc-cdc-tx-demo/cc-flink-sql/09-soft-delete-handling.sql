-- -----------------------------------------------------------------------------
-- Soft Delete Handling
-- Card Transaction Processing Demo
-- -----------------------------------------------------------------------------
-- Demonstrates how to handle DELETE operations from CDC while preserving
-- existing values in the target table (soft delete pattern)
--
-- Use cases:
-- - Audit requirements: Maintain historical data even after deletes
-- - Data retention policies: Keep deleted records for compliance
-- - Downstream processing: Allow downstream systems to handle deletes gracefully
-- - Recovery scenarios: Ability to restore deleted records

-- Pattern 1: Preserve existing values on delete operations
-- When a delete operation is encountered, preserve the existing values
-- in the target table rather than overwriting with NULLs

-- Create a table that tracks deletes separately while preserving data
CREATE TABLE IF NOT EXISTS customers_soft_delete (
    account_number STRING,
    customer_name STRING,
    email STRING,
    phone_number STRING,
    city STRING,
    created_at STRING,
    
    -- CDC metadata
    cdc_operation STRING,
    source_timestamp TIMESTAMP_LTZ(3),
    is_deleted BOOLEAN,
    deleted_at TIMESTAMP_LTZ(3),
    
    -- Processing metadata
    last_updated_at TIMESTAMP_LTZ(3),
    
    PRIMARY KEY (account_number) NOT ENFORCED
) WITH (
    'connector' = 'upsert-kafka',
    'topic' = 'card-tx-customers-soft-delete',
    'properties.bootstrap.servers' = '${KAFKA_BOOTSTRAP_SERVERS}',
    'key.format' = 'avro-confluent',
    'key.avro-confluent.url' = '${SCHEMA_REGISTRY_URL}',
    'value.format' = 'avro-confluent',
    'value.avro-confluent.url' = '${SCHEMA_REGISTRY_URL}'
);

-- Soft delete pattern: Preserve existing values when delete operation is encountered
-- This requires a temporal join or lookup to get existing values

-- Note: In Flink SQL, this pattern works best with:
-- 1. Temporal joins to get the latest state before the delete
-- 2. Upsert-kafka connector which handles deletes automatically
-- 3. Custom logic to preserve values on delete

-- Pattern using CASE statements to conditionally update fields
INSERT INTO customers_soft_delete
SELECT 
    COALESCE(IF(op = 'd', before.account_number, after.account_number), '') AS account_number,
    
    -- Preserve existing value if delete operation, otherwise use new value
    CASE 
        WHEN op = 'd' THEN 
            -- For delete operations, try to preserve existing value
            -- In a real scenario, you'd join with existing table to get current value
            COALESCE(
                IF(op = 'd', before.customer_name, after.customer_name),
                'DELETED'
            )
        ELSE 
            COALESCE(after.customer_name, 'NULL')
    END AS customer_name,
    
    CASE 
        WHEN op = 'd' THEN 
            COALESCE(
                IF(op = 'd', before.email, after.email),
                'DELETED'
            )
        ELSE 
            COALESCE(after.email, 'NULL')
    END AS email,
    
    CASE 
        WHEN op = 'd' THEN 
            COALESCE(
                IF(op = 'd', before.phone_number, after.phone_number),
                'DELETED'
            )
        ELSE 
            COALESCE(after.phone_number, 'NULL')
    END AS phone_number,
    
    CASE 
        WHEN op = 'd' THEN 
            COALESCE(
                IF(op = 'd', before.city, after.city),
                'DELETED'
            )
        ELSE 
            COALESCE(after.city, 'NULL')
    END AS city,
    
    CASE 
        WHEN op = 'd' THEN 
            COALESCE(
                IF(op = 'd', before.created_at, after.created_at),
                'DELETED'
            )
        ELSE 
            COALESCE(after.created_at, 'NULL')
    END AS created_at,
    
    -- CDC metadata
    op AS cdc_operation,
    TO_TIMESTAMP_LTZ(source.ts_ms, 3) AS source_timestamp,
    (op = 'd') AS is_deleted,
    CASE 
        WHEN op = 'd' THEN TO_TIMESTAMP_LTZ(source.ts_ms, 3)
        ELSE NULL
    END AS deleted_at,
    CURRENT_TIMESTAMP AS last_updated_at
    
FROM `card-tx.public.customers`
WHERE source.ts_ms IS NOT NULL;

-- Pattern 2: Using temporal join to preserve existing values
-- This pattern uses Flink's temporal join to get the latest state
-- before applying the delete operation

-- First, create a versioned table that tracks all changes
CREATE TABLE IF NOT EXISTS customers_versioned (
    account_number STRING,
    customer_name STRING,
    email STRING,
    phone_number STRING,
    city STRING,
    created_at STRING,
    cdc_operation STRING,
    source_timestamp TIMESTAMP_LTZ(3),
    PRIMARY KEY (account_number, source_timestamp) NOT ENFORCED
) WITH (
    'connector' = 'kafka',
    'topic' = 'card-tx-customers-versioned',
    'properties.bootstrap.servers' = '${KAFKA_BOOTSTRAP_SERVERS}',
    'value.format' = 'avro-confluent',
    'value.avro-confluent.url' = '${SCHEMA_REGISTRY_URL}'
);

-- Insert all changes (including deletes) into versioned table
INSERT INTO customers_versioned
SELECT 
    COALESCE(IF(op = 'd', before.account_number, after.account_number), '') AS account_number,
    COALESCE(IF(op = 'd', before.customer_name, after.customer_name), 'NULL') AS customer_name,
    COALESCE(IF(op = 'd', before.email, after.email), 'NULL') AS email,
    COALESCE(IF(op = 'd', before.phone_number, after.phone_number), 'NULL') AS phone_number,
    COALESCE(IF(op = 'd', before.city, after.city), 'NULL') AS city,
    COALESCE(IF(op = 'd', before.created_at, after.created_at), 'NULL') AS created_at,
    op AS cdc_operation,
    TO_TIMESTAMP_LTZ(source.ts_ms, 3) AS source_timestamp
FROM `card-tx.public.customers`
WHERE source.ts_ms IS NOT NULL;

-- Pattern 3: Separate delete tracking table
-- Track deletes separately while maintaining full history in main table

CREATE TABLE IF NOT EXISTS customer_deletes (
    account_number STRING,
    deleted_at TIMESTAMP_LTZ(3),
    deleted_by_operation STRING,
    source_timestamp TIMESTAMP_LTZ(3),
    PRIMARY KEY (account_number) NOT ENFORCED
) WITH (
    'connector' = 'upsert-kafka',
    'topic' = 'card-tx-customer-deletes',
    'properties.bootstrap.servers' = '${KAFKA_BOOTSTRAP_SERVERS}',
    'key.format' = 'avro-confluent',
    'key.avro-confluent.url' = '${SCHEMA_REGISTRY_URL}',
    'value.format' = 'avro-confluent',
    'value.avro-confluent.url' = '${SCHEMA_REGISTRY_URL}'
);

-- Track delete operations separately
INSERT INTO customer_deletes
SELECT 
    before.account_number AS account_number,
    TO_TIMESTAMP_LTZ(source.ts_ms, 3) AS deleted_at,
    op AS deleted_by_operation,
    TO_TIMESTAMP_LTZ(source.ts_ms, 3) AS source_timestamp
FROM `card-tx.public.customers`
WHERE op = 'd' AND before.account_number IS NOT NULL;

-- Query to get active customers (excluding deleted ones)
-- SELECT c.*
-- FROM customers_versioned c
-- LEFT JOIN customer_deletes d ON c.account_number = d.account_number
-- WHERE d.account_number IS NULL
--   AND c.cdc_operation != 'd';

-- Query to get all customers including deleted ones with delete status
-- SELECT 
--     c.*,
--     d.deleted_at,
--     CASE WHEN d.account_number IS NOT NULL THEN TRUE ELSE FALSE END AS is_deleted
-- FROM customers_versioned c
-- LEFT JOIN customer_deletes d ON c.account_number = d.account_number;

-- Best practices for soft delete handling:
-- 1. Use upsert-kafka connector which automatically handles deletes as tombstone records
-- 2. For append-only sinks (S3, Iceberg), explicitly track deletes
-- 3. Consider data retention policies - how long to keep deleted records
-- 4. Use separate delete tracking tables for audit purposes
-- 5. Filter deleted records in downstream queries using is_deleted flag
-- 6. For recovery scenarios, maintain full change history

-- Example: Filter out deleted records in downstream processing
-- SELECT *
-- FROM customers_soft_delete
-- WHERE is_deleted = FALSE
--   OR (is_deleted = TRUE AND deleted_at > CURRENT_TIMESTAMP - INTERVAL '30' DAY);
