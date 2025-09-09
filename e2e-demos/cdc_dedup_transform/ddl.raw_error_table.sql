-- Dead Letter Queue (DLQ) Table for Raw Data Processing Errors
-- This table captures records that failed processing along with error metadata
-- Schema matches the main raw_data table with additional error tracking fields

CREATE TABLE raw_error_table (
    -- Original message key (preserved for debugging and potential reprocessing)
    key BYTES,
    
    -- Original CDC headers (preserved exactly as received)
    headers ROW<
        operation STRING,
        changeSequence STRING,
        `timestamp` STRING,
        streamPosition STRING,
        transactionId STRING,
        changeMask STRING,
        columnMask STRING,
        externalSchemaId STRING,
        transactionEventCounter BIGINT,
        transactionLastEvent BOOLEAN
    >,
    
    -- Original data payload as raw bytes (schema-agnostic)
    data BYTES,
    
    -- Original beforeData payload as raw bytes (schema-agnostic)  
    beforeData BYTES,
    
    -- Error tracking metadata
    error_metadata ROW<
        error_message STRING NOT NULL,           -- Detailed error description
        error_code STRING,                       -- Error classification code
        error_timestamp TIMESTAMP_LTZ(3) NOT NULL,  -- When the error occurred
        processing_attempt INT NOT NULL,         -- Number of processing attempts
        source_topic STRING,                     -- Original Kafka topic
        source_partition INT,                    -- Original Kafka partition
        source_offset BIGINT,                    -- Original Kafka offset
        processor_task_id STRING,                -- Flink task that failed
        stack_trace STRING,                      -- Full stack trace (optional)
        can_retry BOOLEAN DEFAULT TRUE,          -- Whether this error is retryable
        quarantine_reason STRING,                -- Why record was quarantined
        source_schema_id STRING,                 -- Schema ID for decoding bytes
        data_format STRING,                      -- Format of the data bytes (json, avro, etc.)
        source_table_name STRING                 -- Original source table name
    >,
    
    -- Processing timestamp for DLQ management
    dlq_ingested_at TIMESTAMP_LTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP

) DISTRIBUTED BY HASH(key) INTO 4 BUCKETS
WITH (
    -- Kafka connector configuration
    'connector' = 'kafka',
    'topic' = 'raw_data_errors',
    'properties.bootstrap.servers' = 'localhost:9092',
    'properties.group.id' = 'raw-data-error-consumer',
    
    -- Data format - using raw bytes for maximum flexibility
    'key.format' = 'raw',
    'value.format' = 'raw',  -- Store complete message as bytes
    
    -- Changelog mode
    'changelog.mode' = 'append',
    
    -- Kafka producer settings for reliability
    'kafka.producer.acks' = 'all',
    'kafka.producer.retries' = '3',
    'kafka.producer.compression.type' = 'snappy',
    
    -- Retention policy for error messages (30 days)
    'kafka.retention.time' = '2592000000',  -- 30 days in ms
    
    -- Performance tuning
    'scan.startup.mode' = 'latest-offset',
    'sink.buffer.size' = '1000',
    'sink.buffer.timeout' = '5s'
);

-- Optional: Create a view for easier querying of error patterns
CREATE VIEW error_summary AS
SELECT 
    error_metadata.error_code,
    error_metadata.error_message,
    COUNT(*) as error_count,
    MIN(error_metadata.error_timestamp) as first_occurrence,
    MAX(error_metadata.error_timestamp) as last_occurrence,
    MAX(error_metadata.processing_attempt) as max_attempts
FROM raw_error_table
WHERE dlq_ingested_at >= CURRENT_TIMESTAMP - INTERVAL '24' HOUR
GROUP BY 
    error_metadata.error_code, 
    error_metadata.error_message
ORDER BY error_count DESC;
