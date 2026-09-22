-- Product catalog reference table.
--
-- Acts as a reference / dimension table joined to tpricelistassignment
-- via CATALOG_UID. Each row represents a distinct catalog (e.g. B2B, B2C,
-- regional). Rows are keyed by UIDPK; a row is replaced when a catalog is
-- renamed or its locale/code changes.
--
-- Topic settings (Confluent Cloud):
--   cleanup.policy  = compact        retain latest value per key
--   retention.time  = 0              infinite retention (dimension table)
--
-- Changelog mode: upsert — a catalog can be renamed; the latest row per
-- UIDPK always wins. Use scan.startup.mode = earliest-offset so a fresh
-- Flink job rebuilds the full snapshot before processing assignments.

CREATE TABLE IF NOT EXISTS tcatalog (
    UIDPK           BIGINT        NOT NULL,
    MASTER          INT,
    NAME            STRING,           -- varchar(255)
    DEFAULT_LOCALE  STRING,           -- varchar(20)
    CATALOG_CODE    STRING,           -- varchar(64)
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
