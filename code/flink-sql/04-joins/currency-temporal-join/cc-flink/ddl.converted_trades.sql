-- Sink: trades enriched with the FX rate that was active at trade time.
--
-- Cardinality notes:
--   One output row per input trade (inner join — trades with no matching FX rate are dropped).
--   If you need all trades regardless of FX availability, change the join to LEFT JOIN and
--   handle NULL rate downstream.

CREATE TABLE IF NOT EXISTS converted_trades (
    trade_id              STRING         NOT NULL,
    trade_ts              TIMESTAMP_LTZ(3),
    base_currency         STRING         NOT NULL,
    quote_currency        STRING         NOT NULL,
    notional_amount       DECIMAL(18, 2) NOT NULL,
    fx_rate               DECIMAL(18, 8),        -- rate at trade_ts; NULL when LEFT JOIN misses
    fx_rate_valid_from    TIMESTAMP_LTZ(3),
    fx_source             STRING,
    converted_amount      DECIMAL(22, 4),        -- notional_amount * fx_rate
    trader_id             STRING,
    desk                  STRING,
    PRIMARY KEY (trade_id) NOT ENFORCED
) DISTRIBUTED BY HASH(trade_id) INTO 6 BUCKETS
WITH (
    'changelog.mode'        = 'append',
    'key.format'            = 'avro-registry',
    'value.format'          = 'avro-registry',
    'value.fields-include'  = 'all'
);
