-- CDC Output Table following Qlik Replicate CDC format
CREATE TABLE qlik_cdc_output_table (
    -- Message key (partition key for ordering)
    key bytes,
    -- Headers: Information about the current record
    headers ROW<
        operation STRING NOT NULL,                    -- REFRESH, INSERT, UPDATE, DELETE
        changeSequence STRING,              -- Monotonically increasing change sequencer
        `timestamp` STRING NOT NULL,                   -- Original change UTC timestamp (CDC operations)
        streamPosition STRING NOT NULL,              -- Source CDC stream position (CDC operations)
        transactionId STRING,               -- Transaction ID (CDC operations)
        changeMask STRING NOT NULL,                  -- Hexadecimal bitmask of changed columns
        columnMask STRING NOT NULL,                  -- Hexadecimal bitmask of present columns
        externalSchemaId STRING NOT NULL,            -- Schema ID for DDL change detection
        transactionEventCounter BIGINT,     -- Sequence number within transaction
        transactionLastEvent BOOLEAN        -- True if final record in transaction
    >,
    -- Data: The current table record data
    data ROW<
        -- Dynamic structure - columns vary by source table
        -- Example for a users table:
        id STRING,
        name STRING,
        email STRING,
        age INT,
        group_id STRING,
        created_at STRING,
        updated_at STRING
    >,
    -- BeforeData: The data before the change (applicable to UPDATE operations)
    beforeData ROW<
        -- Same structure as data
        id STRING,
        name STRING,
        email STRING,
        age INT,
        created_at STRING,
        updated_at STRING
    >
) DISTRIBUTED BY HASH(key) INTO 4 BUCKETS
WITH (
    'changelog.mode' = 'append',
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
