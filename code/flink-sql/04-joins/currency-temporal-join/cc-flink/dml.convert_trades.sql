-- Currency conversion via temporal join: picks the FX rate active at trade_ts.
--
-- FOR SYSTEM_TIME AS OF t.trade_ts performs a point-in-time lookup on fx_rates:
--   Confluent Cloud Flink uses the Kafka message $rowtime of each fx_rates row as
--   the version timestamp. The join picks the fx_rates row with the largest $rowtime
--   still <= t.trade_ts, matching on the PRIMARY KEY columns (from_currency, to_currency).
--
-- fx_rates must be changelog.mode = 'append' so the full rate history is preserved
-- in the topic. With upsert mode only the latest row per key would survive and the
-- temporal join would always return the current rate, not the historical one.
--
-- Key properties:
--   1. Deterministic: each trade is bound to exactly one rate version regardless of
--      when the job runs or restarts.
--   2. Bounded dimension state: Confluent Cloud holds only the snapshot window
--      required by the current probe-side watermark.
--   3. Trades with no matching FX pair are dropped (INNER JOIN semantics).
--      Use LEFT JOIN to pass them through with NULL rate.
--   4. STATE_TTL on the probe side should match the Kafka retention of trades.

INSERT INTO converted_trades
SELECT /*+ STATE_TTL('t'='7d') */
    t.trade_id,
    t.trade_ts,
    t.base_currency,
    t.quote_currency,
    t.notional_amount,
    f.rate                                             AS fx_rate,
    f.valid_from                                       AS fx_rate_valid_from,
    f.source                                           AS fx_source,
    CAST(t.notional_amount * f.rate AS DECIMAL(22, 4)) AS converted_amount,
    t.trader_id,
    t.desk
FROM trades t
INNER JOIN fx_rates FOR SYSTEM_TIME AS OF t.trade_ts AS f
    ON  t.base_currency  = f.from_currency
    AND t.quote_currency = f.to_currency;
