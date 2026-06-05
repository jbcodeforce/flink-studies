{{ config(
    materialized='streaming_table',
    statement_name='fw_crm_txn_customer_equi_ttl',
    tags=['crm'],
    pre_hook=[
        "SET 'sql.state-ttl' = '{{ var('crm_state_ttl') }}'",
    ],
) }}

select
    t.txn_id,
    t.amount,
    t.`timestamp` as txn_time,
    c.customer_name,
    c.created_at as signup_time
from {{ ref('transactions_faker') }} as t
join {{ ref('customers_faker') }} as c
    on t.account_number = c.account_number
