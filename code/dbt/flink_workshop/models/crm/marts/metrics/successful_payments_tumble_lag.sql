{{ config(
    materialized='streaming_table',
    statement_name='fw_crm_successful_payments_tumble_lag',
    tags=['crm'],
) }}

select
    window_start,
    window_end,
    merchant,
    transaction_type,
    count(*) as total_successful,
    lag(count(*), 1) over w as prev_total_successful,
    count(*) - lag(count(*), 1) over w as delta
from tumble(
    table {{ ref('transactions_faker') }},
    descriptor (`timestamp`),
    interval '1' minute
)
where transaction_type = 'payment' and status = 'Successful'
group by
    window_start,
    window_end,
    window_time,
    merchant,
    transaction_type
window w as (
    partition by merchant, transaction_type
    order by window_time
)
