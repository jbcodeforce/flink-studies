-- tbaseamount collapsed to its distinct (start_date, end_date) validity windows.
--
-- tbaseamount holds millions of historical rows, so CROSS/range-JOINing the
-- heartbeat directly against it would mean re-testing every one of those rows
-- on every tick. In practice most rows share one of a much smaller set of
-- (start_date, end_date) pairs (a price list version rolled out on a given day
-- applies to many SKUs with identical bounds) -- grouping first collapses the
-- join target down to just the windows that actually exist, so the heartbeat
-- only ever has to be range-matched against this small set
-- (see ddl.active_base_amount_windows.sql).
--
-- Deterministic by construction -- start_date/end_date come straight from the
-- source rows, no wall-clock function involved.
--
-- Topic settings (Confluent Cloud):
--   cleanup.policy  = compact        retain latest amounts array per window
--   retention.time  = 0              infinite retention -- do not TTL this;
--                                     a window must stay available for as long
--                                     as it could still become active.

CREATE TABLE IF NOT EXISTS base_amount_by_window (
     `OBJECT_GUID`     STRING,
    start_date TIMESTAMP_LTZ(3),
    end_date   TIMESTAMP_LTZ(3),
    amounts ARRAY<ROW<
        `GUID`            STRING,
        `OBJECT_TYPE`     STRING,
        `PRICE_LIST_GUID` STRING,
        `QUANTITY`        DECIMAL(19, 2),
        `LIST`            DECIMAL(19, 2),
        `SALE`            DECIMAL(19, 2)
    >>,
    PRIMARY KEY (OBJECT_GUID, start_date, end_date) NOT ENFORCED
) DISTRIBUTED BY HASH(OBJECT_GUID, start_date, end_date) INTO 6 BUCKETS
WITH (
    'changelog.mode'        = 'upsert',
    'kafka.cleanup-policy'  = 'compact',
    'kafka.retention.time'  = '0',
    'key.format'            = 'avro-registry',
    'value.format'          = 'avro-registry',
    'value.fields-include'  = 'all',
    'scan.startup.mode'     = 'earliest-offset'
);
