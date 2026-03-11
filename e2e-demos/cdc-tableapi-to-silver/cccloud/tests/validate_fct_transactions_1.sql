
WITH expected AS (
    SELECT 'acc_001' AS account_id, CAST(378.75 AS DECIMAL(10, 2)) AS amount
),
actual AS (
    SELECT account_id, sum(amount) as total
    FROM tp_fct_transactions where account_id = 'acc_001'
  group by account_id 
),
check_result AS (
    SELECT
        e.account_id,
        case when a.total = e.amount then 'PASS'
         else 'FAILL'
         end as r
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