-- dlq for raw_data issue
create table raw_error_table(
    key bytes,
    headers row<
        key string,
        value bytes
    >,
    data bytes,
    beforeData bytes

) distributed by hash(key) into 1 buckets with (
    'changelog.mode' = 'append',
    'key.format' = 'raw',
    'value.format' = 'raw'
);