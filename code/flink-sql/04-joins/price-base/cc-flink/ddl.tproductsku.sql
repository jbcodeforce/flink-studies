-- Product SKU reference table.
--
-- Each row represents one sellable SKU (stock-keeping unit) belonging to a
-- product, scoped to a specific catalog via CATALOG_CODE.
-- OBJECT_GUID in tbaseamount references either a Product or a ProductSku;
-- this table provides the lookup for ProductSku entries.
--
-- Relationships:
--   tbaseamount.OBJECT_GUID (where OBJECT_TYPE = 'ProductSku') → tproductsku.GUID
--   tproductsku.CATALOG_CODE → tcatalog.CATALOG_CODE
--
-- Topic settings (Confluent Cloud):
--   cleanup.policy  = compact        retain latest value per key
--   retention.time  = 0              infinite retention (dimension table)
--
-- Changelog mode: upsert — SKU metadata can be updated; only the latest
-- row per UIDPK is needed downstream.

CREATE TABLE IF NOT EXISTS tproductsku (
    UIDPK        BIGINT  NOT NULL,
    GUID         STRING,     -- varchar(64) — referenced by tbaseamount.OBJECT_GUID
    CATALOG_CODE STRING,     -- varchar(64) → tcatalog.CATALOG_CODE
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
