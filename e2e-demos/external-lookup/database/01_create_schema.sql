-- External Lookup Demo - Claims Database Schema
-- This script creates the claims metadata table for the external lookup demonstration

-- Create claims table to store insurance claim metadata
CREATE TABLE IF NOT EXISTS claims (
    claim_id VARCHAR PRIMARY KEY,
    member_id VARCHAR NOT NULL,
    claim_amount DECIMAL(10,2) NOT NULL,
    claim_status VARCHAR CHECK (claim_status IN ('PENDING', 'APPROVED', 'DENIED', 'PROCESSING')) DEFAULT 'PENDING',
    claim_type VARCHAR CHECK (claim_type IN ('MEDICAL', 'DENTAL', 'VISION', 'LIFE', 'DISABILITY')) NOT NULL,
    created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    policy_number VARCHAR,
    provider_id VARCHAR,
    diagnosis_code VARCHAR
);

-- Create index on member_id for efficient lookups
CREATE INDEX IF NOT EXISTS idx_claims_member_id ON claims(member_id);

-- Create index on claim_status for filtering
CREATE INDEX IF NOT EXISTS idx_claims_status ON claims(claim_status);

-- Create index on claim_type for analytics
CREATE INDEX IF NOT EXISTS idx_claims_type ON claims(claim_type);

-- Create index on created_date for time-based queries
CREATE INDEX IF NOT EXISTS idx_claims_created_date ON claims(created_date);

-- Create a view for active claims (non-denied)
CREATE VIEW IF NOT EXISTS active_claims AS
SELECT 
    claim_id,
    member_id,
    claim_amount,
    claim_status,
    claim_type,
    created_date,
    policy_number,
    provider_id
FROM claims 
WHERE claim_status != 'DENIED';
