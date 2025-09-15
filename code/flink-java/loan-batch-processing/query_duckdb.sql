-- DuckDB Query Examples for Fraud Analysis Results (Upsert Mode)
-- Run these queries after the FraudCountTableApiJob completes

-- Connect to DuckDB database
-- duckdb /tmp/fraud_analysis.db

-- View all fraud analysis records (upsert approach - one record per date/type)
SELECT * FROM fraud_analysis ORDER BY analysis_date DESC, analysis_timestamp DESC;

-- Get today's fraud count (most recent upsert)
SELECT 
    analysis_date,
    total_fraudulent_loans,
    analysis_timestamp,
    analysis_type
FROM fraud_analysis 
WHERE analysis_type = 'fraud_count_analysis'
  AND analysis_date = CURRENT_DATE;

-- Get latest fraud count across all dates
SELECT 
    analysis_date,
    total_fraudulent_loans,
    analysis_timestamp,
    analysis_type
FROM fraud_analysis 
WHERE analysis_type = 'fraud_count_analysis'
ORDER BY analysis_date DESC 
LIMIT 1;

-- View fraud trends over time (daily view with upserts)
SELECT 
    analysis_date,
    total_fraudulent_loans,
    analysis_timestamp as last_updated
FROM fraud_analysis 
WHERE analysis_type = 'fraud_count_analysis'
ORDER BY analysis_date DESC;

-- Count unique analysis days
SELECT 
    analysis_type,
    COUNT(DISTINCT analysis_date) as analysis_days,
    MIN(analysis_date) as first_analysis,
    MAX(analysis_date) as latest_analysis,
    MAX(analysis_timestamp) as last_updated
FROM fraud_analysis 
GROUP BY analysis_type;

-- Compare fraud counts over the last 7 days (if you run daily)
SELECT 
    analysis_date,
    total_fraudulent_loans,
    LAG(total_fraudulent_loans) OVER (ORDER BY analysis_date) as previous_day_count,
    total_fraudulent_loans - LAG(total_fraudulent_loans) OVER (ORDER BY analysis_date) as daily_change
FROM fraud_analysis 
WHERE analysis_type = 'fraud_count_analysis'
  AND analysis_date >= CURRENT_DATE - INTERVAL '7 days'
ORDER BY analysis_date DESC;

-- Summary report showing upsert behavior
SELECT 
    'Fraud Analysis Summary' as report_type,
    analysis_date,
    total_fraudulent_loans,
    analysis_timestamp as last_run_time,
    CASE 
        WHEN analysis_date = CURRENT_DATE THEN 'Today'
        WHEN analysis_date = CURRENT_DATE - 1 THEN 'Yesterday'
        ELSE CAST(CURRENT_DATE - analysis_date AS VARCHAR) || ' days ago'
    END as relative_date
FROM fraud_analysis 
WHERE analysis_type = 'fraud_count_analysis'
ORDER BY analysis_date DESC;
