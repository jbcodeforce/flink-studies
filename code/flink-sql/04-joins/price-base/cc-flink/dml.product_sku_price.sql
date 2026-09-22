-- tproductsku ⋈ base_amount_by_window ⋈ price_list_by_window.
--
-- base_amount_by_window.amounts is an array (one entry per PRICE_LIST_GUID the
-- SKU has a base amount in, for that window) — UNNEST it to get one row per
-- price list, then join each entry's PRICE_LIST_GUID against
-- price_list_by_window.GUID to attach that price list's currency and window.
-- That's the two joins needed to connect baseamount to pricelist: one to fan
-- the array back out to rows, one to match PRICE_LIST_GUID = GUID.
--
-- Both base_amount_by_window and price_list_by_window are already
-- heartbeat-filtered to their own currently-active window (see
-- dml.base_amount_by_window.sql / dml.price_list_by_window.sql), so this join
-- itself needs no wall-clock check — plain deterministic join.

INSERT INTO product_sku_price
SELECT
    sku.GUID            AS product_sku_guid,
    sku.CATALOG_CODE    AS catalog_code,
    amt.PRICE_LIST_GUID AS price_list_guid,
    plw.CURRENCY        AS currency,
    amt.QUANTITY        AS quantity,
    amt.`LIST`          AS list_price,
    amt.SALE            AS sale_price,
    baw.start_date      AS baseamount_start,
    baw.end_date        AS baseamount_end,
    plw.start_date      AS pricelist_start,
    plw.end_date        AS pricelist_end
FROM tproductsku sku
INNER JOIN base_amount_by_window baw
    ON baw.OBJECT_GUID = sku.GUID
CROSS JOIN UNNEST(baw.amounts) AS amt(GUID, OBJECT_TYPE, PRICE_LIST_GUID, QUANTITY, `LIST`, SALE)
INNER JOIN price_list_by_window plw
    ON plw.GUID = amt.PRICE_LIST_GUID;
