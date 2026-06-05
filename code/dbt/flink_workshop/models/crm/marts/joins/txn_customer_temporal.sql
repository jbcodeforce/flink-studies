{{ config(
    materialized='streaming_table',
    statement_name='fw_crm_txn_customer_temporal',
    tags=['crm'],
) }}

select
    t.txn_id,
    t.amount,
    t.`timestamp` as txn_time,
    c.customer_name,
    c.created_at as signup_time
from {{ ref('transactions_faker') }} as t
join {{ ref('customers_pk') }} for system_time as of t.`timestamp` as c
    on t.account_number = c.account_number
