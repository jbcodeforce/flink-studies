create table if not exists products (
    product_id STRING primary key not enforced,
    origin STRING,
    description STRING,
    organic BOOLEAN
) DISTRIBUTED into 1 BUCKETS 
with (
    'changelog.mode' = 'append',
    'value.fields-include' = 'all'
);