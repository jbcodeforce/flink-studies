-- Price list reference table.
--
-- A price list defines a named, currency-scoped collection of prices that is
-- assigned to a segment of buyers (via tpricelistassignment) and activated
-- during a time window.  Each row represents one version of a price list.
--
-- Business time semantics (from README):
--   start_date  — the date from which this price list is active for its
--                 buyer class (selling context). Records may arrive months
--                 in advance; the price list must NOT be applied until
--                 current wall-clock time >= start_date.
--   end_date    — after this point the price list is no longer valid and a
--                 retraction must be emitted to downstream systems.
--
-- Relationships:
--   tpricelistassignment.PRLISTDSCR_UID  → tpricelist.UIDPK
--   tbaseamount.PRICE_LIST_GUID          → tpricelist.GUID
--
-- Topic settings (Confluent Cloud):
--   cleanup.policy  = compact        retain latest value per key
--   retention.time  = 0              infinite retention (dimension table)
--
-- Changelog mode: upsert — price list metadata (name, description, dates)
-- can be updated in place; only the current row per UIDPK is needed downstream.

CREATE TABLE IF NOT EXISTS tpricelist (
    UIDPK       BIGINT            NOT NULL,
    GUID        STRING,               -- varchar(64)
    NAME        STRING,               -- varchar(255)
    CURRENCY    STRING,               -- varchar(255) — ISO-4217 currency code
    DESCRIPTION STRING,               -- mediumtext (16277215)
    start_date  TIMESTAMP_LTZ(3),     -- business start: price list becomes active for its buyer class
    end_date    TIMESTAMP_LTZ(3),     -- business end: price list expires
    PRIMARY KEY (UIDPK) NOT ENFORCED
) DISTRIBUTED BY HASH(UIDPK) INTO 4 BUCKETS
WITH (
    'changelog.mode'        = 'upsert',
    'kafka.cleanup-policy'  = 'compact',
    'kafka.retention.time'  = '0',
    'key.format'            = 'avro-registry',
    'value.format'          = 'avro-registry',
    'value.fields-include'  = 'all',
    'scan.startup.mode'     = 'earliest-offset'
);
