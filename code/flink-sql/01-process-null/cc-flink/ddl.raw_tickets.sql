CREATE TABLE raw_tickets (
    case_id STRING,
    description STRING,
    priority INT,
    owner STRING,
    testresults STRING,
    creation_ts TIMESTAMP_LTZ(3)
) WITH (
    'changelog.mode' = 'append',
    'value.format' = 'json-registry'
)