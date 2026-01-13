-- Flink SQL DDL for loan_applications CDC table
-- Consumes Debezium CDC events from Kafka topic

-- Bootstrap server options:
--   From confluent namespace: kafka:9071
--   From other namespaces:   kafka.confluent.svc.cluster.local:9071

CREATE TABLE loan_applications (
    application_id STRING,
    customer_id STRING,
    application_date DATE,
    loan_type STRING,
    loan_amount_requested DOUBLE,
    loan_tenure_months INT,
    interest_rate_offered DOUBLE,
    purpose_of_loan STRING,
    employment_status STRING,
    monthly_income DOUBLE,
    cibil_score INT,
    existing_emis_monthly DOUBLE,
    debt_to_income_ratio DOUBLE,
    property_ownership_status STRING,
    residential_address STRING,
    applicant_age INT,
    gender STRING,
    number_of_dependents INT,
    loan_status STRING,
    fraud_flag BOOLEAN,
    fraud_type STRING,
    PRIMARY KEY (application_id) NOT ENFORCED
) WITH (
    'connector' = 'kafka',
    'topic' = 'cdc.public.loan_applications',
    'properties.bootstrap.servers' = 'kafka.confluent.svc.cluster.local:9071',
    'properties.group.id' = 'flink-cdc-loan-consumer',
    'scan.startup.mode' = 'earliest-offset',
    'format' = 'debezium-json'
);
