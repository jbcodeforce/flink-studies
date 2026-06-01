INSERT INTO user_monthly_totals
with tx_details as (
  SELECT t.user_id, u.full_name, u.email, t.amount, t.ts
  FROM transactions t
  LEFT JOIN users u ON t.user_id = u.user_id
)
SELECT
  user_id, full_name, `full_name`email, window_start AS month_start, SUM(amount)  AS total_amount
FROM TABLE(
  TUMBLE(TABLE tx_details, DESCRIPTOR(ts), INTERVAL '30' DAYS)
)
GROUP BY user_id, full_name, email, window_start;