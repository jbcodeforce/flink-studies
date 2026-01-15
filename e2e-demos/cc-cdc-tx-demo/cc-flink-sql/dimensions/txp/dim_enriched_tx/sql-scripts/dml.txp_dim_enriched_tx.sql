INSERT INTO txp_dim_enriched_tx
with ml_results as (
    select 
      t.txn_id,

      CASE 
        WHEN t.amount > 1000 THEN 0.7
        WHEN t.amount > 500 AND t.transaction_type = 'ONLINE' THEN 0.5
        ELSE 0.1
        END AS fraud_score,
        CASE 
            WHEN t.amount > 1000 THEN 'AMOUNT_ANOMALY'
            WHEN t.amount > 500 AND t.transaction_type = 'ONLINE' THEN 'ONLINE_HIGH_VALUE'
            ELSE 'NORMAL'
        END AS fraud_category,
        CASE 
            WHEN t.amount > 1000 THEN 'HIGH'
            WHEN t.amount > 500 THEN 'MEDIUM'
            ELSE 'LOW'
        END AS risk_level
    from src_txp_transaction t
)
SELECT 
    t.txn_id,
    t.`timestamp`,
    t.amount,
    t.currency,
    t.merchant,
    t.location,
    t.status,
    t.transaction_type,
    -- Customer enrichment
    c.account_number,
    c.customer_name,
    c.email AS customer_email,
    c.city AS customer_city,
    -- ML enrichment (with defaults if not yet processed)
    COALESCE(m.fraud_score, 0.0) AS fraud_score,
    COALESCE(m.fraud_category, 'PENDING') AS fraud_category,
    COALESCE(m.risk_level, 'UNKNOWN') AS risk_level,
    -- Metadata
    CURRENT_TIMESTAMP AS enriched_at
FROM src_txp_transaction t
-- Join with customers using temporal join (latest version)
LEFT JOIN txp_dim_customers as c
    ON t.account_number = c.account_number
-- Join with ML results
LEFT JOIN ml_results AS m
    ON t.txn_id = m.txn_id;