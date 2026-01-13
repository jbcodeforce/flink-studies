-- -----------------------------------------------------------------------------
-- ML Model Enrichment
-- Card Transaction Processing Demo
-- -----------------------------------------------------------------------------
-- Call ML inference endpoint to score transactions for fraud detection
-- and enrich with ML predictions

-- Define the ML inference function (async HTTP call)
-- Note: In Confluent Cloud Flink, use the built-in ML_PREDICT function
-- or HTTP_REQUEST for custom endpoints

-- Output table for ML-enriched transactions
CREATE TABLE IF NOT EXISTS ml_results (
    txn_id STRING,
    account_number STRING,
    `timestamp` TIMESTAMP_LTZ(3),
    amount DECIMAL(10, 2),
    merchant STRING,
    location STRING,
    -- ML predictions
    fraud_score DOUBLE,
    fraud_category STRING,
    risk_level STRING,
    inference_timestamp TIMESTAMP_LTZ(3),
    PRIMARY KEY (txn_id) NOT ENFORCED
) WITH (
    'connector' = 'upsert-kafka',
    'topic' = 'card-tx-ml-results',
    'properties.bootstrap.servers' = '${KAFKA_BOOTSTRAP_SERVERS}',
    'key.format' = 'avro-confluent',
    'key.avro-confluent.url' = '${SCHEMA_REGISTRY_URL}',
    'value.format' = 'avro-confluent',
    'value.avro-confluent.url' = '${SCHEMA_REGISTRY_URL}'
);

-- Option 1: Using Confluent Cloud ML Models (when available)
-- INSERT INTO ml_results
-- SELECT 
--     t.txn_id,
--     t.account_number,
--     t.`timestamp`,
--     t.amount,
--     t.merchant,
--     t.location,
--     ML_PREDICT('fraud-detection-model', t.amount, t.merchant, t.location) AS fraud_score,
--     CASE 
--         WHEN ML_PREDICT('fraud-detection-model', t.amount, t.merchant, t.location) > 0.8 THEN 'HIGH_RISK'
--         WHEN ML_PREDICT('fraud-detection-model', t.amount, t.merchant, t.location) > 0.5 THEN 'MEDIUM_RISK'
--         ELSE 'LOW_RISK'
--     END AS fraud_category,
--     CURRENT_TIMESTAMP AS inference_timestamp
-- FROM transactions t;

-- Option 2: Using HTTP_REQUEST for custom ML endpoint
-- This requires the ML inference service to be deployed and accessible
INSERT INTO ml_results
SELECT 
    t.txn_id,
    t.account_number,
    t.`timestamp`,
    t.amount,
    t.merchant,
    t.location,
    -- Placeholder: Replace with actual ML call
    -- For demo, using a simple rule-based scoring
    CASE 
        WHEN t.amount > 1000 THEN 0.7
        WHEN t.amount > 500 AND t.transaction_type = 'ONLINE' THEN 0.5
        ELSE 0.1
    END AS fraud_score,
    CASE 
        WHEN t.amount > 1000 THEN 'AMOUNT_ANOMALY'
        WHEN t.amount > 500 AND t.transaction_type = 'ONLINE' THEN 'ONLINE_HIGH_VALUE'
        ELSE 'NORMAL'
    END AS fraud_category,
    CASE 
        WHEN t.amount > 1000 THEN 'HIGH'
        WHEN t.amount > 500 THEN 'MEDIUM'
        ELSE 'LOW'
    END AS risk_level,
    CURRENT_TIMESTAMP AS inference_timestamp
FROM transactions t
WHERE t.status = 'PENDING';

-- When CC Flink supports HTTP_REQUEST:
-- INSERT INTO ml_results
-- SELECT 
--     t.txn_id,
--     t.account_number,
--     t.`timestamp`,
--     t.amount,
--     t.merchant,
--     t.location,
--     CAST(JSON_VALUE(
--         HTTP_REQUEST(
--             'POST',
--             'http://ml-inference-service:8080/predict',
--             JSON_OBJECT(
--                 'txn_id' VALUE t.txn_id,
--                 'amount' VALUE t.amount,
--                 'merchant' VALUE t.merchant,
--                 'location' VALUE t.location
--             )
--         ),
--         '$.fraud_score'
--     ) AS DOUBLE) AS fraud_score,
--     JSON_VALUE(
--         HTTP_REQUEST(
--             'POST',
--             'http://ml-inference-service:8080/predict',
--             JSON_OBJECT(
--                 'txn_id' VALUE t.txn_id,
--                 'amount' VALUE t.amount,
--                 'merchant' VALUE t.merchant,
--                 'location' VALUE t.location
--             )
--         ),
--         '$.category'
--     ) AS fraud_category,
--     CURRENT_TIMESTAMP AS inference_timestamp
-- FROM transactions t;
