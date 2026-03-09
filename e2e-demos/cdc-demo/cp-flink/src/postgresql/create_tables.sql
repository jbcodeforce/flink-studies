-- Create tables for CDC demo

CREATE TABLE IF NOT EXISTS loan_applications (
    application_id VARCHAR(255) PRIMARY KEY,
    customer_id VARCHAR(255),
    application_date DATE,
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
);

CREATE TABLE IF NOT EXISTS transactions (
    transaction_id VARCHAR(255) PRIMARY KEY,
    customer_id VARCHAR(255),
    transaction_date TIMESTAMP,
    transaction_type VARCHAR(255),
    transaction_amount FLOAT,
    merchant_category VARCHAR(255),
    merchant_name VARCHAR(255),
    transaction_location VARCHAR(255),
    account_balance_after_transaction FLOAT,
    is_international_transaction BOOLEAN,
    device_used VARCHAR(255),
    ip_address VARCHAR(255),
    transaction_status VARCHAR(255),
    transaction_source_destination VARCHAR(255),
    transaction_notes TEXT,
    fraud_flag BOOLEAN
);

\dt
