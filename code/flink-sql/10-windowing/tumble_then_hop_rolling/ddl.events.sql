-- Bounded datagen source for the two-stage window demo (tumble then hop).
CREATE TABLE IF NOT EXISTS events (
    user_id STRING,
    amount DECIMAL(10, 2),
    seq BIGINT,
    event_time AS TO_TIMESTAMP_LTZ(seq * 60000, 3),
    WATERMARK FOR event_time AS event_time - INTERVAL '1' SECOND
) WITH (
    'connector' = 'datagen',
    'number-of-rows' = '4000',
    'rows-per-second' = '400',
    'fields.user_id.length' = '4',
    'fields.amount.min' = '1.00',
    'fields.amount.max' = '100.00',
    'fields.seq.kind' = 'sequence',
    'fields.seq.start' = '1',
    'fields.seq.end' = '10000000'
);
