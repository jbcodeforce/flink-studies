-- Validate fct_transactions: expect txn_1 (100.00) and txn_2 (50.00) for acc_001.
-- Run after pipeline (raw -> src_transactions -> fct_transactions) has been applied.
WITH expected AS (
    SELECT 'txn_1' AS txn_id, 'acc_001' AS account_id, CAST(100.00 AS DECIMAL(10, 2)) AS amount
    UNION ALL
    SELECT 'txn_2', 'acc_001', CAST(50.00 AS DECIMAL(10, 2))
),
actual AS (
    SELECT txn_id, account_id, amount
    FROM fct_transactions
),
check_result AS (
    SELECT
        e.txn_id,
        CASE
            WHEN a.txn_id IS NULL THEN 'FAIL'
            WHEN a.account_id <> e.account_id THEN 'FAIL'
            WHEN a.amount <> e.amount THEN 'FAIL'
            ELSE 'PASS'
        END AS result
    FROM expected e
    LEFT JOIN actual a ON e.txn_id = a.txn_id
),
overall AS (
    SELECT
        (SELECT COUNT(*) FROM expected) AS expected_count,
        (SELECT COUNT(*) FROM check_result WHERE result = 'PASS') AS pass_count
)
SELECT
    CASE WHEN expected_count = pass_count THEN 'PASS' ELSE 'FAIL' END AS test_result,
    expected_count,
    pass_count
FROM overall;
