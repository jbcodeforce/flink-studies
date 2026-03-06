-- Transaction-level fact from silver (optionally filter by status, e.g. COMPLETED).
INSERT INTO fct_transactions
SELECT
    txn_id,
    account_id,
    amount,
    currency,
    `timestamp`,
    status
FROM src_transactions
WHERE txn_id IS NOT NULL AND txn_id <> '';
