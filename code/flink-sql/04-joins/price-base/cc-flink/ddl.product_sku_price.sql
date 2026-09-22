-- Per-SKU, per-price-list currently active price — the
-- tproductsku ⋈ base_amount_by_window ⋈ price_list_by_window join
-- (see dml.product_sku_price.sql).
--
-- base_amount_by_window is already restricted to windows the heartbeat
-- currently sits inside (per tbaseamount's own start/end), and
-- price_list_by_window is restricted the same way for tpricelist. Joining
-- amounts[].PRICE_LIST_GUID against price_list_by_window.GUID pairs two
-- independently-active windows together — no wall-clock check needed here.
--
-- Keyed by (PRODUCT_SKU_GUID, PRICE_LIST_GUID, QUANTITY): a SKU can be sold
-- under more than one price list/currency at once, and can have more than one
-- quantity tier within the same price list.
--
-- Topic settings (Confluent Cloud):
--   cleanup.policy  = compact        retain latest value per key
--   retention.time  = 0              infinite retention

CREATE TABLE IF NOT EXISTS product_sku_price (
    PRODUCT_SKU_GUID STRING,             -- varchar(64) → tproductsku.GUID
    CATALOG_CODE     STRING,             -- varchar(64)
    PRICE_LIST_GUID  STRING,             -- varchar(64) → tpricelist.GUID
    CURRENCY         STRING,             -- varchar(255) — ISO-4217 currency code
    QUANTITY         DECIMAL(19, 2),
    LIST_PRICE       DECIMAL(19, 2),
    SALE_PRICE       DECIMAL(19, 2),
    BASEAMOUNT_START TIMESTAMP_LTZ(3),   -- tbaseamount.start_date for this window
    BASEAMOUNT_END   TIMESTAMP_LTZ(3),   -- tbaseamount.end_date for this window
    PRICELIST_START  TIMESTAMP_LTZ(3),   -- tpricelist.start_date for this window
    PRICELIST_END    TIMESTAMP_LTZ(3),   -- tpricelist.end_date for this window
    PRIMARY KEY (PRODUCT_SKU_GUID, PRICE_LIST_GUID, QUANTITY) NOT ENFORCED
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
