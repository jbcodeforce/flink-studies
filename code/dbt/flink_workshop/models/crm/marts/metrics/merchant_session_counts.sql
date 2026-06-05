{{ config(
    materialized='streaming_table',
    statement_name='fw_crm_merchant_session_counts',
    tags=['crm'],
) }}

select
    window_start,
    timestampdiff(second, window_start, window_end) as sec_duration,
    merchant,
    count(*) as total_tx
from session(
    data => table {{ ref('transactions_faker') }} partition by merchant,
    timecol => descriptor (`timestamp`),
    gap => interval '5' seconds
)
group by
    window_start,
    window_end,
    merchant
