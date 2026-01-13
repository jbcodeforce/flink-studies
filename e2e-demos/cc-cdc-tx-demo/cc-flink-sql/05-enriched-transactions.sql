-- -----------------------------------------------------------------------------
-- Enriched Transactions
-- Card Transaction Processing Demo
-- -----------------------------------------------------------------------------
-- Join transactions with customer data and ML results
-- to create a fully enriched transaction record

-- Output table for enriched transactions
CREATE TABLE IF NOT EXISTS enriched_transactions (
    -- Transaction fields
    txn_id STRING,
    `timestamp` TIMESTAMP_LTZ(3),
    amount DECIMAL(10, 2),
    currency STRING,
    merchant STRING,
    location STRING,
    status STRING,
    transaction_type STRING,
    -- Customer fields
    account_number STRING,
    customer_name STRING,
    customer_email STRING,
    customer_city STRING,
    -- ML enrichment fields
    fraud_score DOUBLE,
    fraud_category STRING,
    risk_level STRING,
    -- Processing metadata
    enriched_at TIMESTAMP_LTZ(3),
    PRIMARY KEY (txn_id) NOT ENFORCED
) WITH (
    'connector' = 'upsert-kafka',
    'topic' = 'card-tx-enriched-transactions',
    'properties.bootstrap.servers' = '${KAFKA_BOOTSTRAP_SERVERS}',
    'key.format' = 'avro-confluent',
    'key.avro-confluent.url' = '${SCHEMA_REGISTRY_URL}',
    'value.format' = 'avro-confluent',
    'value.avro-confluent.url' = '${SCHEMA_REGISTRY_URL}'
);

-- Enrich transactions with customer data and ML results
INSERT INTO enriched_transactions
SELECT 
    t.txn_id,
    t.`timestamp`,
    t.amount,
    t.currency,
    t.merchant,
    t.location,
    t.status,
    t.transaction_type,
    -- Customer enrichment
    c.account_number,
    c.customer_name,
    c.email AS customer_email,
    c.city AS customer_city,
    -- ML enrichment (with defaults if not yet processed)
    COALESCE(m.fraud_score, 0.0) AS fraud_score,
    COALESCE(m.fraud_category, 'PENDING') AS fraud_category,
    COALESCE(m.risk_level, 'UNKNOWN') AS risk_level,
    -- Metadata
    CURRENT_TIMESTAMP AS enriched_at
FROM transactions t
-- Join with customers using temporal join (latest version)
LEFT JOIN customers FOR SYSTEM_TIME AS OF t.`timestamp` AS c
    ON t.account_number = c.account_number
-- Join with ML results
LEFT JOIN ml_results FOR SYSTEM_TIME AS OF t.`timestamp` AS m
    ON t.txn_id = m.txn_id;

-- Alternative: Simple join without temporal semantics
-- (for environments that don't support temporal joins)
-- INSERT INTO enriched_transactions
-- SELECT 
--     t.txn_id,
--     t.`timestamp`,
--     t.amount,
--     t.currency,
--     t.merchant,
--     t.location,
--     t.status,
--     t.transaction_type,
--     c.account_number,
--     c.customer_name,
--     c.email AS customer_email,
--     c.city AS customer_city,
--     COALESCE(m.fraud_score, 0.0) AS fraud_score,
--     COALESCE(m.fraud_category, 'PENDING') AS fraud_category,
--     COALESCE(m.risk_level, 'UNKNOWN') AS risk_level,
--     CURRENT_TIMESTAMP AS enriched_at
-- FROM transactions t
-- LEFT JOIN customers c ON t.account_number = c.account_number
-- LEFT JOIN ml_results m ON t.txn_id = m.txn_id;
