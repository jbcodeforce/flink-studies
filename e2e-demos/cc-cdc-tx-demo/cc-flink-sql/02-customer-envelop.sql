insert into dim_customers select 
  account_number,
  coalesce(if (op = 'd', before.customer_name, after.customer_name), 'NULL') as customer_name,
  coalesce(if (op = 'd', before.email, after.email), 'NULL') as email,
  coalesce(if (op = 'd', before.phone_number, after.phone_number), 'NULL') as phone_number,
  DATE_FORMAT(if (op = 'd', before.date_of_birth, after.date_of_birth), 'YYYY-MM-DD') as date_of_birth,
  coalesce(if (op = 'd', before.city, after.city), 'NULL') as city,
  coalesce(if (op = 'd', before.created_at, after.created_at), 'NULL') as created_at,
  op,
  TO_TIMESTAMP_LTZ(source.ts_ms, 3) AS ts
from `card-tx.public.customers` 