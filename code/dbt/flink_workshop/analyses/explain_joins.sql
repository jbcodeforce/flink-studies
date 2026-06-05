-- Copy into Flink SQL workspace and prefix with EXPLAIN to inspect physical plans.
-- Equi-join (state TTL never):
-- select ... from transactions_faker t join customers_faker c on t.account_number = c.account_number;
--
-- Interval join:
-- select ... from transactions_faker t join customers_faker c on ...
-- where t.`timestamp` between c.created_at and c.created_at + interval '10' second;

select * from {{ ref('transactions_faker') }} limit 0
