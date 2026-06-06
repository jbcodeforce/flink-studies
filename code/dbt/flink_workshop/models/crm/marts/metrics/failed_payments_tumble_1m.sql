{{ config(
    materialized='streaming_table',
    statement_name='fw_crm_failed_payments_tumble_1m',
    tags=['crm'],
) }}

select
    window_start,
    window_end,
    merchant,
    count(*) as total_tx_failed
from tumble(
    table {{ ref('transactions_faker') }},
    descriptor (pay_timestamp),
    interval '1' minute
)
where transaction_type = 'payment' and status = 'Failed'
group by
    window_start,
    window_end,
    merchant
