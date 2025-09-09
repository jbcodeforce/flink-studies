# Dead Letter Queue (DLQ) Best Practices for Apache Flink SQL

## Overview
This document provides best practices for implementing dead letter queue functionality using the `raw_error_table` DDL and error routing patterns.

## Key Features of the Generic Error Table

### 1. **Schema-Agnostic Design** 
- Uses `BYTES` columns for data payload storage
- No need to modify error table when source schemas change
- Single error table can handle multiple source tables
- Future-proof against schema evolution

### 2. **Complete Message Preservation**
- Preserves the original `key`, `headers` (structured), and raw `data`/`beforeData` (bytes)
- Enables potential reprocessing of failed messages after fixing issues
- Stores format metadata for proper decoding (`data_format`, `source_schema_id`)

### 3. **Rich Error Metadata**
- `error_message`: Human-readable error description
- `error_code`: Categorized error type for automated handling
- `error_timestamp`: When the error occurred
- `processing_attempt`: Number of retry attempts
- `source_topic/partition/offset`: Original Kafka message location
- `can_retry`: Flag indicating if error is retryable
- `source_table_name`: Which table the error originated from

### 4. **Operational Monitoring**
- `dlq_ingested_at`: When record entered DLQ for SLA tracking
- `processor_task_id`: Which Flink task failed for debugging
- Multi-table error tracking and schema version monitoring

## Generic BYTES Approach: Benefits & Trade-offs

### ✅ **Benefits**
- **Schema Independence**: One error table handles all source tables
- **Zero Maintenance**: No DDL changes when source schemas evolve  
- **Format Flexibility**: Works with JSON, Avro, Protobuf, etc.
- **Future Proof**: Handles unknown future data structures
- **Storage Efficiency**: Raw bytes can be more compact than structured columns
- **Exact Preservation**: Stores data exactly as received from Kafka

### ⚠️ **Trade-offs**
- **Query Complexity**: Need to decode bytes for human-readable queries
- **Performance**: JSON parsing required for data access
- **Type Safety**: Less compile-time validation of data structure
- **Debugging**: Requires additional steps to inspect data content

### 🎯 **When to Use Generic BYTES**
- **Multiple source tables** with different schemas
- **Frequent schema changes** in source systems
- **Unknown or evolving** data structures
- **High schema diversity** environments
- **Long-term archival** requirements

### 🎯 **When to Use Structured Columns**
- **Single source table** with stable schema
- **Frequent human analysis** of error data
- **Simple debugging** requirements
- **Performance-critical** error analysis queries

## Configuration Recommendations

### Kafka Topic Configuration
```bash
# Create the error topic with appropriate retention
kafka-topics.sh --create \
  --topic raw_data_errors \
  --bootstrap-server localhost:9092 \
  --partitions 4 \
  --replication-factor 3 \
  --config retention.ms=2592000000 \
  --config compression.type=snappy
```

### Flink Job Configuration
```yaml
# Add to your Flink job configuration
execution:
  checkpointing:
    interval: 60s
    mode: EXACTLY_ONCE
    
state-backend:
  type: rocksdb
  incremental: true

restart-strategy:
  type: fixed-delay
  attempts: 3
  delay: 10s
```

## Error Handling Patterns

### 1. **Validation Errors** (Retryable: Usually No)
```sql
-- Route records with data quality issues
WHERE data.id IS NULL 
   OR NOT (data.email REGEXP '^[A-Za-z0-9+_.-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$')
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

### 2. **Automated Retry Logic**
```sql
-- Implement exponential backoff for retryable errors
-- This would typically be done in a separate Flink job
UPDATE raw_error_table
SET error_metadata.processing_attempt = error_metadata.processing_attempt + 1
WHERE error_metadata.can_retry = TRUE 
  AND error_metadata.processing_attempt < 3
  AND error_metadata.error_timestamp < CURRENT_TIMESTAMP - INTERVAL '1' HOUR;
```

## Alerting Thresholds

### Critical Alerts
- Error rate > 5% of total throughput
- New error codes appearing
- Retryable errors exceeding max attempts

### Warning Alerts  
- Error rate > 1% of total throughput
- DLQ size growing consistently
- Old records in DLQ (> 7 days)

## Cleanup and Maintenance

### Automated Cleanup
```sql
-- Archive old error records (run daily)
CREATE TABLE raw_error_archive AS
SELECT * FROM raw_error_table
WHERE dlq_ingested_at < CURRENT_TIMESTAMP - INTERVAL '30' DAY;

-- Clean up archived records
DELETE FROM raw_error_table
WHERE dlq_ingested_at < CURRENT_TIMESTAMP - INTERVAL '30' DAY;
```

## Performance Considerations

1. **Partitioning**: Use hash partitioning on key for even distribution
2. **Retention**: Set appropriate Kafka retention based on your SLA
3. **Compression**: Use Snappy compression for balance of speed/size
4. **Batching**: Configure appropriate buffer sizes for batch writes
5. **Monitoring**: Regular monitoring prevents DLQ from becoming a bottleneck

## Integration with External Systems

### Slack/Email Notifications
```sql
-- Create a notification trigger (pseudo-code)
-- This would typically integrate with a monitoring system
CREATE TABLE error_notifications AS
SELECT 
    error_metadata.error_code,
    COUNT(*) as error_count,
    'CRITICAL' as severity
FROM raw_error_table
WHERE error_metadata.error_timestamp >= CURRENT_TIMESTAMP - INTERVAL '5' MINUTE
GROUP BY error_metadata.error_code
HAVING COUNT(*) > 100;  -- Threshold for critical errors
```

Remember: The goal is to fail fast, capture everything, and provide actionable information for debugging and recovery.
