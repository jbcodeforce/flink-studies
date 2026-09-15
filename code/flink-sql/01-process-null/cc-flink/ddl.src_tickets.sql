CREATE TABLE src_tickets (
    case_id STRING NOT NULL,
    description STRING,
    priority BIGINT,
    owner STRING,
    testresults STRING,
    creation_ts TIMESTAMP_LTZ(3),
    first_ts TIMESTAMP_LTZ(3),
    PRIMARY KEY(case_id) NOT ENFORCED
) WITH (
    'changelog.mode' = 'upsert',
    'value.format' = 'json-registry'
)