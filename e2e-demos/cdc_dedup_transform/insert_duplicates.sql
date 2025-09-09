execute statement set
begin
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