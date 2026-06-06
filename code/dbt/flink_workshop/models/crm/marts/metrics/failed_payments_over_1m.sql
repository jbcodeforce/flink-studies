{{ config(
    materialized='streaming_table',
    statement_name='fw_crm_failed_payments_over_1m',
    tags=['crm'],
) }}

select
    pay_timestamp,
    merchant,
    count(*) over w as total_tx_failed_last_minute
from {{ ref('transactions_faker') }}
where transaction_type = 'payment' and status = 'Failed'
window w as (
    partition by merchant
    order by pay_timestamp
    range between interval '1' minute preceding and current row
)
