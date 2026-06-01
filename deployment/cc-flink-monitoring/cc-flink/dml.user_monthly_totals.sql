INSERT INTO user_monthly_totals
SELECT
  user_id, full_name, email, window_start AS month_start, SUM(amount)  AS total_amount
FROM TABLE(
  TUMBLE(TABLE transactions, DESCRIPTOR(ts), INTERVAL '30' DAYS)
)
GROUP BY user_id, full_name, email, window_start;