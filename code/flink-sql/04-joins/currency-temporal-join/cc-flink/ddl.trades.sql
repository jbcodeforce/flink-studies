-- Trade events — append-only fact stream (probe side of the temporal join).
--
-- Topic settings:
--   cleanup.policy  = delete             standard append log; no compaction needed
--   retention.ms    = 604800000          7-day retention; adjust for your SLA
--   retention.bytes = -1                 size-based cap disabled; control via time
--
-- Cardinality notes:
--   High-throughput trading systems produce 10 k–500 k trades/s.  Partition by
--   base_currency (or a hash of base+quote) for even distribution.
--   The temporal join reads fx_rates via a point-in-time snapshot — Flink buffers
--   probe records only until the watermark advances past trade_ts, bounded by
--   the watermark lag (5 s here).
--
-- Watermark note for static seed data:
--   INSERT INTO statements produce a bounded stream. Flink advances the watermark
--   to MAX(trade_ts) - 5 s after all rows are inserted, which is enough to emit
--   all join results. In production the watermark advances continuously.

CREATE TABLE IF NOT EXISTS trades (
    trade_id        STRING            NOT NULL,
    trade_ts        TIMESTAMP_LTZ(3),
    base_currency   STRING            NOT NULL,
    quote_currency  STRING            NOT NULL,
    notional_amount DECIMAL(18, 2)    NOT NULL,
    trader_id       STRING,
    desk            STRING,
    PRIMARY KEY (trade_id) NOT ENFORCED,
    WATERMARK FOR trade_ts AS trade_ts - INTERVAL '1' MINUTES
) DISTRIBUTED BY HASH(trade_id) INTO 6 BUCKETS
WITH (
    'changelog.mode'        = 'append',
    'key.format'            = 'avro-registry',
    'value.format'          = 'avro-registry',
    'value.fields-include'  = 'all',
    'scan.startup.mode'     = 'earliest-offset'
);
