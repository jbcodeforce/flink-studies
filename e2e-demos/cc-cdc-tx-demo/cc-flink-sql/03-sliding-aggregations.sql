-- -----------------------------------------------------------------------------
-- Sliding Window Aggregations
-- Card Transaction Processing Demo
-- -----------------------------------------------------------------------------
-- Aggregate transaction amounts by cardholder using sliding windows
-- Windows: 1 minute, 15 minutes, 1 hour, 1 day

-- Output table for aggregations
CREATE TABLE IF NOT EXISTS tx_aggregations (
    account_number STRING,
    window_start TIMESTAMP(3),
    window_end TIMESTAMP(3),
    window_type STRING,
    tx_count BIGINT,
    total_amount DECIMAL(15, 2),
    avg_amount DECIMAL(15, 2),
    min_amount DECIMAL(10, 2),
    max_amount DECIMAL(10, 2),
    PRIMARY KEY (account_number, window_start, window_type) NOT ENFORCED
) WITH (
    'connector' = 'upsert-kafka',
    'topic' = 'card-tx-tx-aggregations',
    'properties.bootstrap.servers' = '${KAFKA_BOOTSTRAP_SERVERS}',
    'key.format' = 'avro-confluent',
    'key.avro-confluent.url' = '${SCHEMA_REGISTRY_URL}',
    'value.format' = 'avro-confluent',
    'value.avro-confluent.url' = '${SCHEMA_REGISTRY_URL}'
);

-- 1-Minute Sliding Window (slide every 30 seconds)
INSERT INTO tx_aggregations
SELECT 
    account_number,
    window_start,
    window_end,
    '1_MINUTE' AS window_type,
    COUNT(*) AS tx_count,
    SUM(amount) AS total_amount,
    AVG(amount) AS avg_amount,
    MIN(amount) AS min_amount,
    MAX(amount) AS max_amount
FROM TABLE(
    HOP(TABLE transactions, DESCRIPTOR(`timestamp`), INTERVAL '30' SECOND, INTERVAL '1' MINUTE)
)
GROUP BY account_number, window_start, window_end;

-- 15-Minute Sliding Window (slide every 5 minutes)
INSERT INTO tx_aggregations
SELECT 
    account_number,
    window_start,
    window_end,
    '15_MINUTE' AS window_type,
    COUNT(*) AS tx_count,
    SUM(amount) AS total_amount,
    AVG(amount) AS avg_amount,
    MIN(amount) AS min_amount,
    MAX(amount) AS max_amount
FROM TABLE(
    HOP(TABLE transactions, DESCRIPTOR(`timestamp`), INTERVAL '5' MINUTE, INTERVAL '15' MINUTE)
)
GROUP BY account_number, window_start, window_end;

-- 1-Hour Sliding Window (slide every 15 minutes)
INSERT INTO tx_aggregations
SELECT 
    account_number,
    window_start,
    window_end,
    '1_HOUR' AS window_type,
    COUNT(*) AS tx_count,
    SUM(amount) AS total_amount,
    AVG(amount) AS avg_amount,
    MIN(amount) AS min_amount,
    MAX(amount) AS max_amount
FROM TABLE(
    HOP(TABLE transactions, DESCRIPTOR(`timestamp`), INTERVAL '15' MINUTE, INTERVAL '1' HOUR)
)
GROUP BY account_number, window_start, window_end;

-- 1-Day Tumbling Window
INSERT INTO tx_aggregations
SELECT 
    account_number,
    window_start,
    window_end,
    '1_DAY' AS window_type,
    COUNT(*) AS tx_count,
    SUM(amount) AS total_amount,
    AVG(amount) AS avg_amount,
    MIN(amount) AS min_amount,
    MAX(amount) AS max_amount
FROM TABLE(
    TUMBLE(TABLE transactions, DESCRIPTOR(`timestamp`), INTERVAL '1' DAY)
)
GROUP BY account_number, window_start, window_end;
