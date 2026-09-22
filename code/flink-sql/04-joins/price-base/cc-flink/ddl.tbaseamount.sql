-- Base amount (price entry) table — versioned fact/dimension.
--
-- Each row records the list price and sale price for one product object
-- (identified by OBJECT_GUID + OBJECT_TYPE) within a specific price list
-- (PRICE_LIST_GUID → tpricelist.GUID), at a given quantity threshold.
--
-- Business time semantics:
--   start_date  — the date from which this price is available for sale.
--                 Records may arrive months in advance; a price must NOT be
--                 applied until the current wall-clock time >= start_date.
--   end_date    — after this point the price is no longer valid and a
--                 deletion / retraction must be propagated downstream.
--
-- These two temporal conditions combine with tpricelist's own start/end
-- window to determine whether a price is "active" for a given buyer class
-- at the current instant.
--
-- Changelog mode: upsert — prices are updated (e.g. SALE price changes)
-- while retaining the same UIDPK. Only the latest row per key is needed
-- for point-in-time price resolution.
--
-- Topic settings (Confluent Cloud):
--   cleanup.policy  = compact        retain latest value per key
--   retention.time  = 0              infinite retention
--
-- Partitioning by PRICE_LIST_GUID co-locates all prices for the same list,
-- making joins against tpricelist efficient without shuffle.

CREATE TABLE IF NOT EXISTS tbaseamount (
    UIDPK           BIGINT          NOT NULL,
    GUID            STRING,             -- varchar(64)
    OBJECT_GUID     STRING,             -- varchar(64)  — references the priced object (product/SKU)
    OBJECT_TYPE     STRING,             -- varchar(100) — discriminator: 'Product', 'ProductSku', etc.
    QUANTITY        DECIMAL(19, 2),
    LIST            DECIMAL(19, 2),     -- list price
    SALE            DECIMAL(19, 2),     -- sale / promotional price
    PRICE_LIST_GUID STRING,             -- varchar(64)  → tpricelist.GUID
    start_date      TIMESTAMP_LTZ(3),   -- business start: price becomes applicable
    end_date        TIMESTAMP_LTZ(3),   -- business end: price expires
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
