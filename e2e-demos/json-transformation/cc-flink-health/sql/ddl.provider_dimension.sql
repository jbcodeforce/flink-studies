CREATE TABLE provider_dimension (
    provider_id STRING,
    first_name STRING,
    last_name STRING,
    specialty STRING,
    primary_location ROW(
        facility_name STRING,
        address ROW(
            street STRING,
            city STRING,
            state STRING,
            zip STRING
        )
    ),
    contact_number STRING,
    npi_number STRING,
    PRIMARY KEY (provider_id) NOT ENFORCED
) WITH (
    'key.format' = 'json-registry',
    'value.format' = 'json-registry',
    'changelog.mode' = 'upsert'
);
