{{ config(
    materialized='streaming_table',
    statement_name='fw_crm_withdrawal_running_totals',
    tags=['crm'],
) }}

select
    account_number,
    transaction_type,
    amount,
    sum(amount) over w as total_value,
    case when sum(amount) over w > 500 then 'YES' else 'NO' end as flag
from {{ ref('transactions_faker') }}
where transaction_type = 'withdrawal'
window w as (
    partition by account_number, transaction_type
    order by `timestamp` asc
    range between interval '1' hour preceding and current row
)
