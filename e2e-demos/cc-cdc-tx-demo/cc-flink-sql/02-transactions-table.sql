-- -----------------------------------------------------------------------------
-- Transactions Table Definition
-- Card Transaction Processing Demo
-- -----------------------------------------------------------------------------
-- This table reads from the CDC Debezium topic for transactions
-- with proper watermark for event-time processing

CREATE TABLE IF NOT EXISTS transactions (
    txn_id STRING,
    account_number STRING,
    `timestamp` TIMESTAMP_LTZ(3),
    amount DECIMAL(10, 2),
    currency STRING,
    merchant STRING,
    location STRING,
    status STRING,
    transaction_type STRING,
    -- Metadata from Kafka
    `partition` INT METADATA FROM 'partition' VIRTUAL,
    `offset` BIGINT METADATA FROM 'offset' VIRTUAL,
    -- Watermark for event-time processing
    WATERMARK FOR `timestamp` AS `timestamp` - INTERVAL '5' SECOND,
    -- Primary key for upsert semantics
    PRIMARY KEY (txn_id) NOT ENFORCED
) WITH (
    'connector' = 'kafka',
    'topic' = 'card-tx.public.transactions',
    'properties.bootstrap.servers' = '${KAFKA_BOOTSTRAP_SERVERS}',
    'properties.group.id' = 'card-tx-flink-transactions',
    'scan.startup.mode' = 'earliest-offset',
    'value.format' = 'avro-confluent',
    'value.avro-confluent.url' = '${SCHEMA_REGISTRY_URL}',
    'value.avro-confluent.basic-auth.credentials-source' = 'USER_INFO',
    'value.avro-confluent.basic-auth.user-info' = '${SR_API_KEY}:${SR_API_SECRET}'
);

-- Alternative: If using Confluent Cloud Flink with catalog integration,
-- the table is auto-registered from the topic schema:
-- USE CATALOG `card-tx-environment-xxx`;
-- USE DATABASE `card-tx-cluster-xxx`;
-- SELECT * FROM `card-tx.public.transactions`;
