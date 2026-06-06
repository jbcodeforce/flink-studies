{{ config(
    materialized='streaming_table',
    statement_name='fw_crm_merchant_session_counts',
    tags=['crm'],
) }}

SELECT
    window_start,
    timestampdiff(second, window_start, window_end) as sec_duration,
    merchant,
    count(*) as total_tx
FROM SESSION(
    DATA => table {{ ref('transactions_faker') }} PARTITION BY merchant,
    TIMECOL => descriptor (pay_timestamp),
    GAP => interval '5' seconds
)
GROUP BY
    window_start,
    window_end,
    merchant
