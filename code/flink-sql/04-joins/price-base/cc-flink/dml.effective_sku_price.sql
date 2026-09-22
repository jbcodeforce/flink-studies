-- Heartbeat-driven alternative to letting the reader apply the current-time
-- filter (compare dml.insert_effective_sku_price.sql). Every heartbeat tick
-- CROSS JOINs against effective_sku_price and re-upserts every SKU's row, so
-- Flink itself flips STATUS to 'EXPIRED' (and nulls the prices) once a tick
-- lands past EFFECTIVE_END, and back to 'ACTIVE' once a tick lands past
-- EFFECTIVE_START -- no downstream read-time filter required.
--
-- Deploy ddl/data for effective_sku_price first; this reuses its deterministic
-- EFFECTIVE_START/EFFECTIVE_END computation instead of re-doing the 3-way join.
--
-- Trade-off vs. the deferred-filter version: activation/expiry latency is
-- bounded by how often dml.insert_heartbeat_tick.sql runs, and this query holds
-- state for every (SKU) row across ticks (small and bounded for a dimension
-- table of this size, but grows with SKU count).

INSERT INTO effective_sku_price
SELECT
    c.PRODUCT_SKU_GUID,
    c.CATALOG_CODE,
    c.PRICE_LIST_GUID,
    c.CURRENCY,
    c.QUANTITY,
    CASE WHEN hb.tick_ts >= c.EFFECTIVE_START AND hb.tick_ts < c.EFFECTIVE_END
         THEN c.LIST_PRICE END                                            AS list_price,
    CASE WHEN hb.tick_ts >= c.EFFECTIVE_START AND hb.tick_ts < c.EFFECTIVE_END
         THEN c.SALE_PRICE END                                            AS sale_price,
    CASE WHEN hb.tick_ts >= c.EFFECTIVE_START AND hb.tick_ts < c.EFFECTIVE_END
         THEN 'ACTIVE' ELSE 'EXPIRED' END                                  AS status,
    hb.tick_ts                                                            AS as_of
FROM heartbeat hb
CROSS JOIN effective_sku_price c;
