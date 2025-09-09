

## Error Handling Patterns

### 1. **Validation Errors** (Retryable: Usually No)
```sql
-- Route records with data quality issues
WHERE data.id IS NULL 
   OR NOT REGEXP(email,'^[A-Za-z0-9+_.-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$')
```

### 2. **Parsing Errors** (Retryable: Usually No)
```sql
-- Route records with unparseable timestamps
WHERE TRY_TO_TIMESTAMP_LTZ(headers.timestamp, 'yyyy-MM-dd HH:mm:ss.SSS') IS NULL
```

### 3. **Processing Errors** (Retryable: Maybe)
```sql
-- Use try-catch patterns for complex transformations
-- Set can_retry = TRUE for transient errors
-- Set can_retry = FALSE for data corruption
```

## Monitoring Queries

### Error Rate Dashboard
```sql
-- Hourly error rate
SELECT 
    TUMBLE_START(error_metadata.error_timestamp, INTERVAL '1' HOUR) as hour,
    error_metadata.error_code,
    COUNT(*) as error_count
FROM raw_error_table
WHERE error_metadata.error_timestamp >= CURRENT_TIMESTAMP - INTERVAL '24' HOUR
GROUP BY 
    TUMBLE(error_metadata.error_timestamp, INTERVAL '1' HOUR),
    error_metadata.error_code;
```

### Top Error Patterns
```sql
-- Most frequent errors in last 24 hours
SELECT 
    error_metadata.error_code,
    error_metadata.error_message,
    COUNT(*) as frequency,
    COUNT(DISTINCT data.id) as unique_records_affected
FROM raw_error_table
WHERE error_metadata.error_timestamp >= CURRENT_TIMESTAMP - INTERVAL '24' HOUR
GROUP BY error_metadata.error_code, error_metadata.error_message
ORDER BY frequency DESC
LIMIT 10;
```

## Working with BYTES Data

### Decoding Stored Bytes
```sql
-- Decode JSON bytes to readable format
SELECT 
    error_metadata.source_table_name,
    JSON_VALUE(CAST(data AS STRING), '$.id') as record_id,
    JSON_VALUE(CAST(data AS STRING), '$.email') as email_value,
    error_metadata.error_message
FROM raw_error_table
WHERE error_metadata.data_format = 'json'
  AND error_metadata.error_code = 'VALIDATION_ERROR';

-- Create a reusable view for decoded customer data
CREATE VIEW decoded_customer_errors AS
SELECT 
    key,
    headers,
    JSON_VALUE(CAST(data AS STRING), '$.id') as customer_id,
    JSON_VALUE(CAST(data AS STRING), '$.name') as name,
    JSON_VALUE(CAST(data AS STRING), '$.email') as email,
    CAST(JSON_VALUE(CAST(data AS STRING), '$.age') AS INT) as age,
    error_metadata
FROM raw_error_table
WHERE error_metadata.source_table_name = 'customers'
  AND error_metadata.data_format = 'json';
```

### Schema Registry Integration (for Avro)
```sql
-- For Avro format with Schema Registry
SELECT 
    error_metadata.source_table_name,
    error_metadata.schema_registry_id,
    -- Would use appropriate Avro decoding functions
    -- AVRO_DECODE(data, error_metadata.schema_registry_id) as decoded_data
FROM raw_error_table
WHERE error_metadata.data_format = 'avro';
```

## Reprocessing Failed Records

### 1. **Manual Reprocessing with BYTES**
```sql
-- Create corrected records by decoding bytes and applying fixes
CREATE TEMPORARY TABLE corrected_customer_records AS
SELECT 
    key,
    headers,
    -- Decode bytes and apply corrections, then re-encode
    CAST(JSON_OBJECT(
        'id', COALESCE(JSON_VALUE(CAST(data AS STRING), '$.id'), 
                      CONCAT('MISSING_ID_', CAST(UNIX_TIMESTAMP() AS STRING))),
        'name', REGEXP_REPLACE(JSON_VALUE(CAST(data AS STRING), '$.name'), '[^a-zA-Z0-9 ]', ''),
        'email', LOWER(TRIM(JSON_VALUE(CAST(data AS STRING), '$.email'))),
        'age', CASE 
                 WHEN CAST(JSON_VALUE(CAST(data AS STRING), '$.age') AS INT) < 0 
                 THEN CAST(NULL AS INT)
                 ELSE CAST(JSON_VALUE(CAST(data AS STRING), '$.age') AS INT)
               END,
        'created_at', JSON_VALUE(CAST(data AS STRING), '$.created_at'),
        'updated_at', JSON_VALUE(CAST(data AS STRING), '$.updated_at')
    ) AS BYTES) as corrected_data
FROM raw_error_table
WHERE error_metadata.can_retry = TRUE
  AND error_metadata.error_code = 'VALIDATION_ERROR'
  AND error_metadata.source_table_name = 'customers'
  AND error_metadata.data_format = 'json';

-- Reprocess corrected records by decoding the corrected bytes
INSERT INTO src_customers
SELECT 
    JSON_VALUE(CAST(corrected_data AS STRING), '$.id') as customer_id,
    MD5(CONCAT_WS('|', 
        JSON_VALUE(CAST(corrected_data AS STRING), '$.id'),
        JSON_VALUE(CAST(corrected_data AS STRING), '$.name'),
        JSON_VALUE(CAST(corrected_data AS STRING), '$.email')
    )) as rec_pk_hash,
    JSON_VALUE(CAST(corrected_data AS STRING), '$.name') as name,
    'system' as rec_create_user_name,
    'system' as rec_update_user_name,
    JSON_VALUE(CAST(corrected_data AS STRING), '$.email') as email,
    CAST(JSON_VALUE(CAST(corrected_data AS STRING), '$.age') AS INT) as age,
    TO_TIMESTAMP_LTZ(JSON_VALUE(CAST(corrected_data AS STRING), '$.created_at'), 'yyyy-MM-dd HH:mm:ss') as rec_created_ts,
    TO_TIMESTAMP_LTZ(JSON_VALUE(CAST(corrected_data AS STRING), '$.updated_at'), 'yyyy-MM-dd HH:mm:ss') as rec_updated_ts,
    'RETRY' as rec_crud_text,
    headers.changeSequence as hdr_changeSequence,
    headers.`timestamp` as hdr_timestamp,
    CURRENT_TIMESTAMP as tx_ts,
    0 as delete_ind,
    MD5(CONCAT_WS('|',
        JSON_VALUE(CAST(corrected_data AS STRING), '$.name'),
        JSON_VALUE(CAST(corrected_data AS STRING), '$.email'),
        JSON_VALUE(CAST(corrected_data AS STRING), '$.age')
    )) as rec_row_hash
FROM corrected_customer_records;
```