-- Validate dim_account: expect acc_001 with account_name = 'Acme North Ltd', region = 'NORTH'.
-- Run after pipeline (raw -> src_accounts -> dim_account) has been applied.

WITH expected AS (
    SELECT 'acc_001' AS account_id, 'Acme North Ltd' AS account_name, 'NORTH' AS region
),
actual AS (
    SELECT account_id, account_name, region
    FROM tp_dim_accounts
    WHERE account_id = 'acc_001' AND (is_deleted IS NULL OR is_deleted = FALSE)
),
check_result AS (
    SELECT
        e.account_id,
        CASE
            WHEN a.account_id IS NULL THEN 'FAIL'
            WHEN a.account_name <> e.account_name THEN 'FAIL'
            WHEN a.region <> e.region THEN 'FAIL'
            ELSE 'PASS'
        END AS r
    FROM expected e
    LEFT JOIN actual a ON e.account_id = a.account_id
),
overall AS (
    SELECT
        (SELECT COUNT(*) FROM expected) AS expected_count,
        (SELECT COUNT(*) FROM check_result WHERE r = 'PASS') AS pass_count
)
SELECT
    CASE WHEN expected_count = pass_count THEN 'PASS' ELSE 'FAIL' END AS test_result,
    expected_count,
    pass_count
FROM overall;
