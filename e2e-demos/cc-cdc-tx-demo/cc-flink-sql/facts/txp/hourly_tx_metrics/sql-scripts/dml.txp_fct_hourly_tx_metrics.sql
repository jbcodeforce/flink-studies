INSERT INTO txp_fct_hourly_tx_metrics
with completed_tx as (
  select * from `src_txp_transaction` where status = 'COMPLETED'
)
SELECT 
    account_number,
    window_start,
    window_end,
    '1_HOUR' AS window_type,
    COUNT(*) AS tx_count,
    SUM(amount) AS total_amount,
    AVG(amount) AS avg_amount,
    MIN(amount) AS min_amount,
    MAX(amount) AS max_amount
FROM TABLE(
    TUMBLE(TABLE completed_tx, DESCRIPTOR(`timestamp`), INTERVAL '1' HOUR)
)
GROUP BY account_number, window_start, window_end;