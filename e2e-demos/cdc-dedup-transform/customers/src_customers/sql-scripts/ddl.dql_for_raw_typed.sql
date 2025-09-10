-- dlq for raw_data issue, need to match the raw_table schema
create table raw_error_table(
    key bytes,
    headers row<
        operation string,
        changeSequence string,
        `timestamp` string,
        streamPosition string,
        transactionId string,
        changeMask string,
        columnMask string,
        externalSchemaId string,
        transactionEventCounter bigint,
        transactionLastEvent boolean
    >,
    data row<id STRING,
        name STRING,
        email STRING,
        age INT,
        group_id STRING,
        created_at STRING,
        updated_at STRING>,
    beforeData row<id STRING,
        name STRING,
        email STRING,
        age INT,
        group_id STRING,
        created_at STRING,
        updated_at STRING>

) distributed by hash(key) into 1 buckets with (
    'changelog.mode' = 'append',
    'key.format' = 'raw',
    'value.format' = 'avro-registry'
);