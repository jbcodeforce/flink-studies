create table if not exists loans (
    application_id VARCHAR(255) PRIMARY KEY NOT ENFORCED,
    customer_id VARCHAR(255),
    application_date VARCHAR(30),
    loan_type VARCHAR(255),
    loan_amount_requested FLOAT,
    loan_tenure_months INT,
    interest_rate_offered FLOAT,
    purpose_of_loan VARCHAR(255),
    employment_status VARCHAR(255),
    monthly_income FLOAT,   
    cibil_score INT,
    existing_emis_monthly FLOAT,
    debt_to_income_ratio FLOAT,
    property_ownership_status VARCHAR(255),
    residential_address VARCHAR(255),
    applicant_age INT,  
    gender VARCHAR(255),
    number_of_dependents INT,
    loan_status VARCHAR(255),
    fraud_flag BOOLEAN,
    fraud_type VARCHAR(255)
) with (
    'connector' = 'filesystem',
    'path' = '../../e2e-demos/cdc-demo/datasets/loan_applications.csv',
    'format' = 'csv'
);