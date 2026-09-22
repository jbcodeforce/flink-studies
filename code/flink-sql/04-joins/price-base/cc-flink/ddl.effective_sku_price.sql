-- Effective SKU price — sink of the 3-way join (tproductsku ⋈ tbaseamount ⋈ tpricelist).
--
-- Flink cannot use CURRENT_TIMESTAMP/CURRENT_DATE in a continuous query to decide
-- whether "now" falls inside [start_date, end_date): that predicate is only
-- re-evaluated when a new input row arrives, so a SKU that becomes active or
-- expires with no new upstream event would never flip state — non-deterministic
-- and effectively broken for this use case.
--
-- Instead this table holds, per SKU, the deterministic effective window computed
-- from the source rows (no wall-clock functions involved):
--   EFFECTIVE_START = GREATEST(tbaseamount.start_date, tpricelist.start_date)
--   EFFECTIVE_END   = LEAST(tbaseamount.end_date, tpricelist.end_date)
--
-- Consumers apply the current-time filter at read time, e.g.:
--   SELECT * FROM effective_sku_price
--   WHERE EFFECTIVE_START <= CURRENT_TIMESTAMP AND CURRENT_TIMESTAMP < EFFECTIVE_END;
--
-- Keyed by PRODUCT_SKU_GUID only: if a SKU is ever active in more than one price
-- list at the same time (e.g. two currencies), only the most-recently-updated one
-- survives here — use (PRODUCT_SKU_GUID, PRICE_LIST_GUID) as the key instead if
-- that must be supported.
--
-- Topic settings (Confluent Cloud):
--   cleanup.policy  = compact        retain latest value per key
--   retention.time  = 0              infinite retention

CREATE TABLE IF NOT EXISTS effective_sku_price (
    PRODUCT_SKU_GUID STRING,             -- varchar(64) → tproductsku.GUID
    CATALOG_CODE     STRING,             -- varchar(64)
    PRICE_LIST_GUID  STRING,             -- varchar(64) → tpricelist.GUID
    CURRENCY         STRING,             -- varchar(255) — ISO-4217 currency code
    QUANTITY         DECIMAL(19, 2),
    LIST_PRICE       DECIMAL(19, 2),
    SALE_PRICE       DECIMAL(19, 2),
    EFFECTIVE_START  TIMESTAMP_LTZ(3),   -- GREATEST(tbaseamount.start_date, tpricelist.start_date)
    EFFECTIVE_END    TIMESTAMP_LTZ(3),   -- LEAST(tbaseamount.end_date, tpricelist.end_date)
    PRIMARY KEY (PRODUCT_SKU_GUID) NOT ENFORCED
) DISTRIBUTED BY HASH(PRODUCT_SKU_GUID) INTO 4 BUCKETS
WITH (
    'changelog.mode'        = 'upsert',
    'kafka.cleanup-policy'  = 'compact',
    'kafka.retention.time'  = '0',
    'key.format'            = 'avro-registry',
    'value.format'          = 'avro-registry',
    'value.fields-include'  = 'all',
    'scan.startup.mode'     = 'earliest-offset'
);
