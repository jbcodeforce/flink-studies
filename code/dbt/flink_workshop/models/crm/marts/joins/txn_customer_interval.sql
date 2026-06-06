{{ config(
    materialized='streaming_table',
    statement_name='fw_crm_txn_customer_interval',
    tags=['crm'],
) }}

select
    t.txn_id,
    t.amount,
    t.pay_timestamp as txn_time,
    c.customer_name,
    c.created_at as signup_time
from {{ ref('transactions_faker') }} as t
join {{ ref('customers_faker') }} as c
    on t.account_number = c.account_number
where t.pay_timestamp between c.created_at and c.created_at + interval '10' second
