-- -----------------------------------------------------------------------------
-- Database Schema for Card Transaction Demo
-- -----------------------------------------------------------------------------
-- Run this SQL file manually if Terraform cannot create tables automatically
-- Usage: psql -h <rds-endpoint> -U postgres -d cardtxdb -f schema.sql

-- Customers table
CREATE TABLE IF NOT EXISTS customers (
    account_number VARCHAR(50) PRIMARY KEY,
    customer_name VARCHAR(255) NOT NULL,
    email VARCHAR(255),
    phone_number VARCHAR(50),
    date_of_birth TIMESTAMP(3),
    city VARCHAR(100),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Transactions table
CREATE TABLE IF NOT EXISTS transactions (
    txn_id VARCHAR(36) PRIMARY KEY,
    account_number VARCHAR(255) NOT NULL REFERENCES customers(account_number),
    timestamp TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    amount DECIMAL(10,2) NOT NULL,
    currency VARCHAR(5) DEFAULT 'USD',
    merchant VARCHAR(255),
    location VARCHAR(255),
    status VARCHAR(255) DEFAULT 'PENDING',
    transaction_type VARCHAR(50)
);

-- Create indexes for transaction lookups
CREATE INDEX IF NOT EXISTS idx_transactions_account 
  ON transactions(account_number);
CREATE INDEX IF NOT EXISTS idx_transactions_timestamp 
  ON transactions(timestamp);
