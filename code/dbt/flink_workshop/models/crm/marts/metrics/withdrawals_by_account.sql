{{ config(
    materialized='streaming_table',
    statement_name='fw_crm_withdrawals_by_account',
    tags=['crm'],
    with = {
    'changelog.mode': 'upsert'
    }
) }}

select
    account_number,
    transaction_type,
    sum(amount) as total_withdrawn
from {{ ref('transactions_faker') }}
where transaction_type = 'withdrawal'
group by account_number, transaction_type
having sum(amount) > 500
