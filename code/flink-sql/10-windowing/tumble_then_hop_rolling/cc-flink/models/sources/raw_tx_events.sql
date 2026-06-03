{{ config(
    materialized='streaming_source',
    connector='faker',
    with = {
    
    'number-of-rows' : '40000',
    'rows-per-second' : '400',
    'fields.user_id.expression' : '#{numerify ''user_##''}',
    'fields.amount.min' : '1.00',
    'fields.amount.max' : '100.00',
    'fields.seq.kind' : 'sequence',
    'fields.seq.start' : '1',
    'fields.seq.end' : '10000000',
    'fields.event_time.format' : 'yyyy-MM-dd HH:mm:ss'
    }
  )
}}

    user_id STRING,
    amount DECIMAL(10, 2),
    seq BIGINT,
    event_time AS TO_TIMESTAMP_LTZ(seq * 60000, 3),
    WATERMARK FOR event_time AS event_time - INTERVAL '1' SECOND
 