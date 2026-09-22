-- Price list assignment — central fact/bridge table.
--
-- Each row binds a price list (PRLISTDSCR_UID → tpricelist) to a catalog
-- (CATALOG_UID → tcatalog) and a selling context (SELLING_CTX_UID →
-- tsellingcontext).  When all three reference records are present AND the
-- current wall-clock time falls within both tpricelist.start_date/end_date
-- AND tbaseamount.start_date/end_date, the associated prices are "active"
-- and must be projected to the output topic.
--
-- Business rules (from README):
--   1. tbaseamount.start_date  — when the product is available for sale.
--   2. tpricelist.start_date   — when the price list is active for that
--                                buyer class (selling context).
--   Both conditions must hold simultaneously for a price to apply.
--   Records may arrive months in advance; they must be held back until
--   both windows open.  Once either window closes, a retraction / delete
--   must be emitted to downstream systems.
--
-- PRIORITY: lower value = higher precedence.  When multiple assignments
-- match the same buyer + catalog, the lowest PRIORITY wins.
--
-- Changelog mode: upsert — assignments can be updated (e.g. priority
-- change, catalog re-assignment).
--
-- Topic settings (Confluent Cloud):
--   cleanup.policy  = compact        retain latest value per key
--   retention.time  = 0              infinite retention
--
-- Partitioning by CATALOG_UID keeps all assignments for a given catalog
-- co-located, reducing shuffle in catalog-scoped joins.

CREATE TABLE IF NOT EXISTS tpricelistassignment (
    UIDPK           BIGINT   NOT NULL,
    GUID            STRING,              -- varchar(64)
    NAME            STRING,              -- varchar(255)
    DESCRIPTION     STRING,              -- varchar(4000)
    PRIORITY        INT,
    CATALOG_UID     BIGINT,              -- FK → tcatalog.UIDPK
    PRLISTDSCR_UID  BIGINT,              -- FK → tpricelist.UIDPK
    SELLING_CTX_UID BIGINT,              -- FK → tsellingcontext.UIDPK
    PRIMARY KEY (UIDPK) NOT ENFORCED
) DISTRIBUTED BY HASH(UIDPK) INTO 6 BUCKETS
WITH (
    'changelog.mode'        = 'upsert',
    'kafka.cleanup-policy'  = 'compact',
    'kafka.retention.time'  = '0',
    'key.format'            = 'avro-registry',
    'value.format'          = 'avro-registry',
    'value.fields-include'  = 'all',
    'scan.startup.mode'     = 'earliest-offset'
);
