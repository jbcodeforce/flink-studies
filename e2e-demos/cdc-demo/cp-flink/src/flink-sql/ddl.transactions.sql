-- Flink SQL DDL for transactions CDC table
-- Consumes Debezium CDC events from Kafka topic

-- Bootstrap server options:
--   From confluent namespace: kafka:9071
--   From other namespaces:   kafka.confluent.svc.cluster.local:9071

CREATE TABLE transactions (
    transaction_id STRING,
    customer_id STRING,
    transaction_date TIMESTAMP(3),
    transaction_type STRING,
    transaction_amount DOUBLE,
    merchant_category STRING,
    merchant_name STRING,
    transaction_location STRING,
    account_balance_after_transaction DOUBLE,
    is_international_transaction BOOLEAN,
    device_used STRING,
    ip_address STRING,
    transaction_status STRING,
    transaction_source_destination STRING,
    transaction_notes STRING,
    fraud_flag BOOLEAN,
    PRIMARY KEY (transaction_id) NOT ENFORCED
) WITH (
    'connector' = 'kafka',
    'topic' = 'cdc.public.transactions',
    'properties.bootstrap.servers' = 'kafka.confluent.svc.cluster.local:9071',
    'properties.group.id' = 'flink-cdc-tx-consumer',
    'scan.startup.mode' = 'earliest-offset',
    'format' = 'debezium-json'
);
