execute statement set 
begin

-- Sample REFRESH operation (Full Load)
INSERT INTO qlik_cdc_output_table VALUES (
    cast('user_001' as  bytes),  -- key
    ROW(
        'REFRESH',                          -- operation
        '1000001',                          -- changeSequence
        cast (null as string),              -- timestamp (null for Full Load)
        cast (null as string),              -- streamPosition (null for Full Load)
        cast (null as string),              -- transactionId (null for Full Load)
        'FF',                               -- changeMask (all columns present)
        'FF',                               -- columnMask (all columns present)
        'schema_v1',                        -- externalSchemaId
        cast(null as integer),              -- transactionEventCounter
        cast(null as boolean)                               -- transactionLastEvent
    ),
    ROW('user_001', 'John Doe', 'john@example.com', 30, '2024-01-01T10:00:00Z', '2024-01-01T10:00:00Z'),  -- data
    CAST(NULL AS ROW<id STRING, name STRING, email STRING, age INT, created_at STRING, updated_at STRING>)  -- beforeData (null for REFRESH)
);

-- Sample INSERT operation (CDC)
INSERT INTO qlik_cdc_output_table VALUES (
    cast('user_002' as bytes),  -- key
    ROW(
        'INSERT',                           -- operation
        '1000002',                          -- changeSequence
        '2024-01-01T12:30:00Z',            -- timestamp
        'lsn:123456',                       -- streamPosition
        'tx_12345',                         -- transactionId
        'FF',                               -- changeMask (all columns inserted)
        'FF',                               -- columnMask (all columns present)
        'schema_v1',                        -- externalSchemaId
        1,                                  -- transactionEventCounter
        true                                -- transactionLastEvent
    ),
    ROW('user_002', 'Jane Smith', 'jane@example.com', 28, '2024-01-01T12:30:00Z', '2024-01-01T12:30:00Z'),  -- data
     CAST(NULL AS ROW<id STRING, name STRING, email STRING, age INT, created_at STRING, updated_at STRING>)   -- beforeData (null for INSERT)
);

-- Sample UPDATE operation (CDC)
INSERT INTO qlik_cdc_output_table VALUES (
    cast('user_001' as bytes),  -- key
    ROW(
        'UPDATE',                           -- operation
        '1000003',                          -- changeSequence
        '2024-01-01T14:45:00Z',            --  tx timestamp
        'lsn:123457',                       -- streamPosition
        'tx_12346',                         -- transactionId
        '0C',                               -- changeMask (hex: 1100 = columns 2,3 changed - email,age)
        'FF',                               -- columnMask (all columns present)
        'schema_v1',                        -- externalSchemaId
        1,                                  -- transactionEventCounter
        true                                -- transactionLastEvent
    ),
    -- data (after change)
    ROW('user_001', 'John Doe', 'john.doe@company.com', 31, '2024-01-01T10:00:00Z', '2024-01-01T14:45:00Z'),
    -- beforeData (before change)
    ROW('user_001', 'John Doe', 'john@example.com', 30, '2024-01-01T10:00:00Z', '2024-01-01T10:00:00Z')
);

-- Sample DELETE operation (CDC)
INSERT INTO qlik_cdc_output_table VALUES (
    cast('user_002' as bytes),  -- key
    ROW(
        'DELETE',                           -- operation
        '1000004',                          -- changeSequence
        '2024-01-01T16:20:00Z',            -- timestamp
        'lsn:123458',                       -- streamPosition
        'tx_12347',                         -- transactionId
        '01',                               -- changeMask (hex: 0001 = only PK column for DELETE)
        'FF',                               -- columnMask (all columns present)
        'schema_v1',                        -- externalSchemaId
        1,                                  -- transactionEventCounter
        true                                -- transactionLastEvent
    ),
     CAST(NULL AS ROW<id STRING, name STRING, email STRING, age INT, created_at STRING, updated_at STRING>) ,  -- data (null for DELETE)
    -- beforeData (deleted record)
    ROW('user_002', 'Jane Smith', 'jane@example.com', 28, '2024-01-01T12:30:00Z', '2024-01-01T12:30:00Z')
);

-- insert wrong data to test dlq
INSERT INTO qlik_cdc_output_table VALUES (
    cast('wrong_user' as bytes),  -- key
    ROW(
        'INSERT',                           -- operation
        '1000005',                          -- changeSequence
        '2024-01-02T12:30:00Z',            -- timestamp
        'lsn:123456',                       -- streamPosition
        'tx_12345',                         -- transactionId
        'FF',                               -- changeMask (all columns inserted)
        'FF',                               -- columnMask (all columns present)
        'schema_v1',                        -- externalSchemaId
        1,                                  -- transactionEventCounter
        true                                -- transactionLastEvent
    ),
    CAST(NULL AS ROW<id STRING, name STRING, email STRING, age INT, created_at STRING, updated_at STRING>),  -- data
    ROW('wrong_user', 'Bob the builder', 'bob_builder@example.com', 28, '2024-02-01T12:30:00Z', '2024-02-01T12:30:00Z')   -- beforeData (null for INSERT)
);

-- insert wrong data to test dlq
INSERT INTO qlik_cdc_output_table VALUES (
    cast('wrong_user' as bytes),  -- key
    ROW(
        'INSERT',                           -- operation
        '1000006',                          -- changeSequence
        '2024-01-03T12:30:00Z',            -- timestamp
        'lsn:123457',                       -- streamPosition
        'tx_1237',                         -- transactionId
        'FF',                               -- changeMask (all columns inserted)
        'FF',                               -- columnMask (all columns present)
        'schema_v1',                        -- externalSchemaId
        1,                                  -- transactionEventCounter
        true                                -- transactionLastEvent
    ),
    CAST(NULL AS ROW<id STRING, name STRING, email STRING, age INT, created_at STRING, updated_at STRING>),  -- data
    CAST(NULL AS ROW<id STRING, name STRING, email STRING, age INT, created_at STRING, updated_at STRING>)   -- beforeData (null for INSERT)
);

-- create duplicates
INSERT INTO qlik_cdc_output_table VALUES (
    cast('user_006' as  bytes),  -- key
    ROW(
        'INSERT',                           -- operation
        '1000012',                          -- changeSequence
        '2024-03-01 12:30:00Z',            -- timestamp
        'lsn:123456',                       -- streamPosition
        'tx_12345',                         -- transactionId
        'FF',                               -- changeMask (all columns inserted)
        'FF',                               -- columnMask (all columns present)
        'schema_v1',                        -- externalSchemaId
        1,                                  -- transactionEventCounter
        true                                -- transactionLastEvent
    ),
    ROW('user_006', 'Robert Smith', 'rsmith@example.com', 50, '2024-03-01T12:30:00Z', '2024-03-01T12:30:00Z'),  -- data
     CAST(NULL AS ROW<id STRING, name STRING, email STRING, age INT, created_at STRING, updated_at STRING>)   -- beforeData (null for INSERT)
);
INSERT INTO qlik_cdc_output_table VALUES (
     cast('user_006' as  bytes),  -- key
    ROW(
        'INSERT',                           -- operation
        '1000012',                          -- changeSequence
        '2024-03-01 12:30:00Z',            -- timestamp
        'lsn:123456',                       -- streamPosition
        'tx_12345',                         -- transactionId
        'FF',                               -- changeMask (all columns inserted)
        'FF',                               -- columnMask (all columns present)
        'schema_v1',                        -- externalSchemaId
        1,                                  -- transactionEventCounter
        true                                -- transactionLastEvent
    ),
    ROW('user_006', 'Robert Smith', 'rsmith@example.com', 50, '2024-03-01T12:30:00Z', '2024-03-01T12:30:00Z'),  -- data
     CAST(NULL AS ROW<id STRING, name STRING, email STRING, age INT, created_at STRING, updated_at STRING>)   -- beforeData (null for INSERT)
);

end;