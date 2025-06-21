with tx as (
    select 
      transaction_id,
      customer_id,
      to_timestamp(transaction_date, 'yyyy-MM-dd HH:mm:ss') as tx_ts,
      transaction_type,
      transaction_amount
    from transactions
) 
select 
    transaction_id,
    customer_id,
    tx_ts,
    transaction_type,
    MAX(transaction_amount) as max_tx_amount
    FROM TABLE(
        TUMBLE(
            TABLE tx,
            DESCRIPTOR(tx_ts),
            INTERVAL '10' MINUTES
        )
    )
    GROUP BY window_start, window_end ;