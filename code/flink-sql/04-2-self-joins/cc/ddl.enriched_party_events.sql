-- Enriched output: each incoming event expanded to all accounts in the party,
-- with subscription details from a self-join on event_stream.
CREATE TABLE IF NOT EXISTS enriched_party_events (
    party_id STRING NOT NULL,
    account_number STRING NOT NULL,
    plan_name STRING,
    subscription_start STRING,
    device_id STRING,
    addr_street STRING,
    addr_city STRING,
    addr_state STRING,
    addr_zip STRING,
    isTrial BOOLEAN,
    PRIMARY KEY (party_id, account_number) NOT ENFORCED
) DISTRIBUTED BY (party_id, account_number ) INTO  4 BUCKETS
WITH (
    'changelog.mode' = 'upsert',
    'key.format' = 'avro-registry',
    'value.format' = 'avro-registry'
);
