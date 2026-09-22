-- Heartbeat — a single evolving "current time" row used to drive periodic
-- re-evaluation of the effective-price window (see dml.insert_heartbeat_tick.sql
-- and dml.insert_effective_sku_price_live.sql).
--
-- Why this exists: CURRENT_TIMESTAMP/CURRENT_DATE is only ever re-evaluated by a
-- continuous query when a new input row arrives. Dimension rows in
-- effective_sku_price have no natural event at the moment their window opens or
-- closes, so a query that tried to filter them with "now()" directly would never
-- flip state on its own. Baking "now" into a real, periodically-arriving event
-- instead — this table — turns the problem into an ordinary join: every tick is
-- a genuinely new row, so CROSS JOINing it against effective_sku_price re-runs
-- the window check on a real trigger instead of hoping a re-evaluation happens.
--
-- tick_id is always 1 — this is intentionally a single-row table (upsert), not
-- an unbounded append log, so downstream state stays tiny regardless of how
-- often it ticks.
--
-- Topic settings (Confluent Cloud):
--   cleanup.policy  = compact        single key, latest tick only
--   retention.time  = 0              infinite retention

CREATE TABLE IF NOT EXISTS heartbeat (
    tick_id BIGINT,             -- constant: 1
    tick_ts TIMESTAMP_LTZ(3),   -- wall-clock time captured by whoever inserted this tick
    PRIMARY KEY (tick_id) NOT ENFORCED
) DISTRIBUTED BY HASH(tick_id) INTO 1 BUCKETS
WITH (
    'changelog.mode'        = 'upsert',
    'kafka.cleanup-policy'  = 'compact',
    'kafka.retention.time'  = '0',
    'key.format'            = 'avro-registry',
    'value.format'          = 'avro-registry',
    'value.fields-include'  = 'all',
    'scan.startup.mode'     = 'earliest-offset'
);
