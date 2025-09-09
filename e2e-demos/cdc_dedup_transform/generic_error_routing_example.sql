-- Generic Error Routing Example using BYTES columns
-- This approach works with any source table schema

-- 1. Generic error routing function using JSON serialization
-- Route any processing errors to the generic DLQ

INSERT INTO raw_error_table
SELECT 
    key,
    headers,
    -- Serialize the data ROW to bytes using JSON format
    CAST(TO_JSON(data) AS BYTES) as data,
    -- Serialize the beforeData ROW to bytes using JSON format  
    CAST(TO_JSON(beforeData) AS BYTES) as beforeData,
    ROW(
        error_message,
        error_code,
        CURRENT_TIMESTAMP,                         -- error_timestamp
        1,                                         -- processing_attempt
        'raw_data_topic',                          -- source_topic
        NULL,                                      -- source_partition
        NULL,                                      -- source_offset  
        'generic-validation-task',                 -- processor_task_id
        NULL,                                      -- stack_trace
        TRUE,                                      -- can_retry
        quarantine_reason,                         -- quarantine_reason
        headers.externalSchemaId,                  -- source_schema_id
        'json',                                    -- data_format
        'customers'                                -- source_table_name
    ) as error_metadata,
    CURRENT_TIMESTAMP as dlq_ingested_at
FROM (
    SELECT 
        key,
        headers,
        data,
        beforeData,
        -- Dynamic error message generation
        CASE 
            WHEN JSON_VALUE(TO_JSON(data), '$.id') IS NULL 
                THEN 'Missing required field: id'
            WHEN JSON_VALUE(TO_JSON(data), '$.email') IS NULL 
                THEN 'Missing required field: email'
            WHEN NOT (JSON_VALUE(TO_JSON(data), '$.email') REGEXP '^[A-Za-z0-9+_.-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$') 
                THEN CONCAT('Invalid email format: ', JSON_VALUE(TO_JSON(data), '$.email'))
            ELSE 'Generic validation error'
        END as error_message,
        'VALIDATION_ERROR' as error_code,
        'Failed generic data validation' as quarantine_reason
    FROM qlik_cdc_output_table
    WHERE 
        -- Generic validation using JSON path expressions
        JSON_VALUE(TO_JSON(data), '$.id') IS NULL
        OR JSON_VALUE(TO_JSON(data), '$.email') IS NULL  
        OR NOT (JSON_VALUE(TO_JSON(data), '$.email') REGEXP '^[A-Za-z0-9+_.-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$')
);

-- 2. Alternative: Store raw Kafka message bytes directly (most generic approach)
-- This version captures the exact bytes from Kafka without any parsing

CREATE TABLE ultra_generic_error_table (
    -- Kafka message metadata
    kafka_key BYTES,
    kafka_headers MAP<STRING, BYTES>,
    kafka_value BYTES,
    
    -- Error tracking
    error_metadata ROW<
        error_message STRING NOT NULL,
        error_code STRING,
        error_timestamp TIMESTAMP_LTZ(3) NOT NULL,
        processing_attempt INT NOT NULL,
        source_topic STRING,
        source_partition INT,
        source_offset BIGINT,
        processor_task_id STRING,
        stack_trace STRING,
        can_retry BOOLEAN DEFAULT TRUE,
        quarantine_reason STRING,
        original_format STRING,                    -- 'avro', 'json', 'protobuf', etc.
        schema_registry_id INT,                    -- Schema Registry ID if applicable
        source_table_name STRING
    >,
    
    dlq_ingested_at TIMESTAMP_LTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP

) DISTRIBUTED BY HASH(kafka_key) INTO 4 BUCKETS
WITH (
    'connector' = 'kafka',
    'topic' = 'ultra_generic_errors',
    'properties.bootstrap.servers' = 'localhost:9092',
    'key.format' = 'raw',
    'value.format' = 'raw',
    'changelog.mode' = 'append'
);

-- 3. Reprocessing: Decode bytes back to structured data
-- Example of how to decode JSON bytes back to structured data

CREATE VIEW decoded_errors AS
SELECT 
    key,
    headers,
    -- Decode JSON bytes back to structured data
    JSON_VALUE(CAST(data AS STRING), '$.id') as customer_id,
    JSON_VALUE(CAST(data AS STRING), '$.name') as customer_name,
    JSON_VALUE(CAST(data AS STRING), '$.email') as customer_email,
    CAST(JSON_VALUE(CAST(data AS STRING), '$.age') AS INT) as customer_age,
    JSON_VALUE(CAST(data AS STRING), '$.created_at') as created_at,
    JSON_VALUE(CAST(data AS STRING), '$.updated_at') as updated_at,
    error_metadata
FROM raw_error_table
WHERE error_metadata.data_format = 'json';

-- 4. Multi-table error routing (works for any source table)
-- Generic pattern that can handle different table schemas

INSERT INTO raw_error_table
SELECT 
    source_key,
    source_headers,
    CAST(source_data AS BYTES),
    CAST(source_before_data AS BYTES),
    ROW(
        error_msg,
        'GENERIC_ERROR',
        CURRENT_TIMESTAMP,
        1,
        source_topic_name,
        NULL,
        NULL,
        'multi-table-processor',
        NULL,
        TRUE,
        'Multi-table processing error',
        source_schema_id,
        'json',
        table_name
    ),
    CURRENT_TIMESTAMP
FROM (
    -- Union different source tables with errors
    SELECT 
        key as source_key,
        headers as source_headers,
        TO_JSON(data) as source_data,
        TO_JSON(beforeData) as source_before_data,
        'Failed processing customers table' as error_msg,
        'customers_raw' as source_topic_name,
        headers.externalSchemaId as source_schema_id,
        'customers' as table_name
    FROM qlik_cdc_output_table  -- customers table
    WHERE /* your error conditions */
    
    UNION ALL
    
    SELECT 
        key as source_key,
        headers as source_headers, 
        TO_JSON(data) as source_data,
        TO_JSON(beforeData) as source_before_data,
        'Failed processing orders table' as error_msg,
        'orders_raw' as source_topic_name,
        headers.externalSchemaId as source_schema_id,
        'orders' as table_name  
    FROM orders_cdc_output_table  -- orders table (example)
    WHERE /* your error conditions */
);

-- 5. Schema evolution handling
-- When source schemas change, the error table continues to work

CREATE OR REPLACE VIEW current_schema_errors AS
SELECT 
    error_metadata.source_table_name,
    error_metadata.source_schema_id,
    COUNT(*) as error_count,
    MIN(error_metadata.error_timestamp) as first_error,
    MAX(error_metadata.error_timestamp) as latest_error
FROM raw_error_table
WHERE dlq_ingested_at >= CURRENT_TIMESTAMP - INTERVAL '24' HOUR
GROUP BY 
    error_metadata.source_table_name,
    error_metadata.source_schema_id
ORDER BY error_count DESC;

-- 6. Monitoring query for generic error table
SELECT 
    error_metadata.source_table_name,
    error_metadata.error_code,
    error_metadata.data_format,
    COUNT(*) as error_count,
    COUNT(DISTINCT error_metadata.source_schema_id) as schema_variants
FROM raw_error_table
WHERE error_metadata.error_timestamp >= CURRENT_TIMESTAMP - INTERVAL '1' HOUR
GROUP BY 
    error_metadata.source_table_name,
    error_metadata.error_code,
    error_metadata.data_format
ORDER BY error_count DESC;
