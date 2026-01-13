-- Sample Flink SQL queries for CDC demo
-- Run these after creating the tables from ddl.loan_applications.sql and ddl.transactions.sql

-- ============================================================
-- Query 1: View all loan applications (streaming)
-- ============================================================
SELECT 
    application_id,
    customer_id,
    loan_type,
    loan_amount_requested,
    loan_status,
    fraud_flag
FROM loan_applications;

-- ============================================================
-- Query 2: View all transactions (streaming)
-- ============================================================
SELECT 
    transaction_id,
    customer_id,
    transaction_date,
    transaction_type,
    transaction_amount,
    transaction_status
FROM transactions;

-- ============================================================
-- Query 3: Count loan applications by status
-- ============================================================
SELECT 
    loan_status,
    COUNT(*) as count
FROM loan_applications
GROUP BY loan_status;

-- ============================================================
-- Query 4: Count transactions by type
-- ============================================================
SELECT 
    transaction_type,
    COUNT(*) as count,
    SUM(transaction_amount) as total_amount
FROM transactions
GROUP BY transaction_type;

-- ============================================================
-- Query 5: High-value transactions (over 50000)
-- ============================================================
SELECT 
    transaction_id,
    customer_id,
    transaction_amount,
    merchant_name,
    transaction_location
FROM transactions
WHERE transaction_amount > 50000;

-- ============================================================
-- Query 6: Flagged fraud applications
-- ============================================================
SELECT 
    application_id,
    customer_id,
    loan_type,
    loan_amount_requested,
    fraud_type
FROM loan_applications
WHERE fraud_flag = TRUE;

-- ============================================================
-- Query 7: Join transactions with loan applications by customer
-- ============================================================
SELECT 
    t.customer_id,
    t.transaction_id,
    t.transaction_amount,
    t.transaction_type,
    l.application_id,
    l.loan_type,
    l.loan_status
FROM transactions t
LEFT JOIN loan_applications l
    ON t.customer_id = l.customer_id;

-- ============================================================
-- Query 8: International transactions summary
-- ============================================================
SELECT 
    customer_id,
    COUNT(*) as intl_tx_count,
    SUM(transaction_amount) as total_intl_amount
FROM transactions
WHERE is_international_transaction = TRUE
GROUP BY customer_id;
