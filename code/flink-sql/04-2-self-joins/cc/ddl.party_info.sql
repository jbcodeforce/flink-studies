-- Compact party-to-account reference (topic: party_info).
-- Composite key party_id + account_id; retained forever as Flink upsert table.
CREATE TABLE IF NOT EXISTS party_info (
    party_id STRING,
    account_number STRING,
    plan_name STRING,
    subscription_start TIMESTAMP_LTZ(3),
    addr_street STRING,
    addr_city STRING,
    addr_state STRING,
    addr_zip STRING,
    updated_at TIMESTAMP_LTZ(3),
    PRIMARY KEY (party_id, account_number) NOT ENFORCED
) DISTRIBUTED BY HASH(party_id, account_number) INTO 4 BUCKETS
WITH (
    'changelog.mode' = 'upsert',
    'key.format' = 'avro-registry',
    'value.format' = 'avro-registry'
);
