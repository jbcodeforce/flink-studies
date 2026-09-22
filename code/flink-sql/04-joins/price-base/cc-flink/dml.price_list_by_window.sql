-- Groups tpricelist by its (GUID, start_date, end_date) window, restricted to
-- windows the heartbeat is currently inside. Mirrors
-- dml.base_amount_by_window.sql's pattern for tpricelist instead of
-- tbaseamount. See ddl.tpricelist_by_window.sql.

INSERT INTO price_list_by_window
SELECT
    pl.GUID,
    pl.start_date,
    pl.end_date,
    pl.CURRENCY
FROM heartbeat hb
INNER JOIN tpricelist pl
    ON  hb.tick_ts >= pl.start_date
    AND hb.tick_ts <  pl.end_date
GROUP BY pl.GUID, pl.start_date, pl.end_date, pl.CURRENCY;