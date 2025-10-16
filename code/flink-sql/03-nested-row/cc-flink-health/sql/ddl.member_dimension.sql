-- Member sink table
CREATE TABLE member_dimension (
    member_id STRING,
    first_name STRING,
    last_name STRING,
    date_of_birth STRING,
    address ROW(
        street STRING,
        city STRING,
        state STRING,
        zip STRING
    ),
    phone STRING,
    email STRING,
    PRIMARY KEY (member_id) NOT ENFORCED
) distributed by hash(member_id) into 2 buckets WITH (
    'key.format' = 'json-registry',
    'value.format' = 'json-registry',
    'changelog.mode' = 'upsert'
);
