-- Example: How to Route Errors to Dead Letter Queue
-- This shows how to implement error handling in your data pipeline

-- 1. Main processing pipeline with error handling
INSERT INTO src_customers
SELECT 
    data.id as customer_id,
    -- Generate hash for deduplication
    MD5(CONCAT_WS('|', 
        COALESCE(data.id, ''),
        COALESCE(data.name, ''),
        COALESCE(data.email, '')
    )) as rec_pk_hash,
    data.name,
    'system' as rec_create_user_name,
    'system' as rec_update_user_name,
    data.email,
    data.age,
    -- Parse timestamp with error handling
    CASE 
        WHEN data.created_at IS NOT NULL AND data.created_at != '' 
        THEN TO_TIMESTAMP_LTZ(data.created_at, 'yyyy-MM-dd HH:mm:ss')
        ELSE CURRENT_TIMESTAMP
    END as rec_created_ts,
    CASE 
        WHEN data.updated_at IS NOT NULL AND data.updated_at != '' 
        THEN TO_TIMESTAMP_LTZ(data.updated_at, 'yyyy-MM-dd HH:mm:ss')
        ELSE CURRENT_TIMESTAMP
    END as rec_updated_ts,
    headers.operation as rec_crud_text,
    headers.changeSequence as hdr_changeSequence,
    headers.`timestamp` as hdr_timestamp,
    TO_TIMESTAMP_LTZ(headers.`timestamp`, 'yyyy-MM-dd HH:mm:ss.SSS') as tx_ts,
    CASE WHEN headers.operation = 'DELETE' THEN 1 ELSE 0 END as delete_ind,
    -- Generate row hash for change detection
    MD5(CONCAT_WS('|',
        COALESCE(data.name, ''),
        COALESCE(data.email, ''),
        COALESCE(CAST(data.age AS STRING), '')
    )) as rec_row_hash
FROM qlik_cdc_output_table
WHERE 
    -- Only process valid records
    data.id IS NOT NULL 
    AND data.id != ''
    AND data.email IS NOT NULL
    AND data.email != ''
    AND data.email REGEXP '^[A-Za-z0-9+_.-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'  -- Basic email validation
    AND (data.age IS NULL OR data.age >= 0);  -- Age validation

-- 2. Route invalid records to dead letter queue
INSERT INTO raw_error_table
SELECT 
    key,
    headers,
    data,
    beforeData,
    ROW(
        -- Generate appropriate error message based on validation failures
        CASE 
            WHEN data.id IS NULL OR data.id = '' 
                THEN 'Missing or empty customer ID'
            WHEN data.email IS NULL OR data.email = '' 
                THEN 'Missing or empty email'
            WHEN NOT (data.email REGEXP '^[A-Za-z0-9+_.-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$') 
                THEN CONCAT('Invalid email format: ', data.email)
            WHEN data.age IS NOT NULL AND data.age < 0 
                THEN CONCAT('Invalid age value: ', CAST(data.age AS STRING))
            ELSE 'Unknown validation error'
        END,
        'VALIDATION_ERROR',                    -- error_code
        CURRENT_TIMESTAMP,                     -- error_timestamp
        1,                                     -- processing_attempt
        'raw_data_topic',                      -- source_topic (adjust as needed)
        NULL,                                  -- source_partition
        NULL,                                  -- source_offset
        'validation-task',                     -- processor_task_id
        NULL,                                  -- stack_trace
        TRUE,                                  -- can_retry
        'Data validation failed'               -- quarantine_reason
    ) as error_metadata,
    CURRENT_TIMESTAMP as dlq_ingested_at
FROM qlik_cdc_output_table
WHERE 
    -- Route records that fail validation
    data.id IS NULL 
    OR data.id = ''
    OR data.email IS NULL
    OR data.email = ''
    OR NOT (data.email REGEXP '^[A-Za-z0-9+_.-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$')
    OR (data.age IS NOT NULL AND data.age < 0);

-- 3. Example: Try-catch pattern using Flink SQL for parsing errors
INSERT INTO raw_error_table
SELECT 
    key,
    headers,
    data,
    beforeData,
    ROW(
        CONCAT('Date parsing failed for timestamp: ', headers.`timestamp`),
        'PARSING_ERROR',
        CURRENT_TIMESTAMP,
        1,
        'raw_data_topic',
        NULL,
        NULL,
        'timestamp-parser-task',
        NULL,
        TRUE,
        'Unable to parse timestamp format'
    ) as error_metadata,
    CURRENT_TIMESTAMP as dlq_ingested_at
FROM qlik_cdc_output_table
WHERE 
    headers.`timestamp` IS NOT NULL 
    AND headers.`timestamp` != ''
    AND TRY_TO_TIMESTAMP_LTZ(headers.`timestamp`, 'yyyy-MM-dd HH:mm:ss.SSS') IS NULL;

-- 4. Monitoring query to track error patterns
SELECT 
    error_metadata.error_code,
    COUNT(*) as error_count,
    COUNT(DISTINCT data.id) as affected_records,
    MIN(error_metadata.error_timestamp) as first_seen,
    MAX(error_metadata.error_timestamp) as last_seen
FROM raw_error_table
WHERE error_metadata.error_timestamp >= CURRENT_TIMESTAMP - INTERVAL '1' HOUR
GROUP BY error_metadata.error_code
ORDER BY error_count DESC;
