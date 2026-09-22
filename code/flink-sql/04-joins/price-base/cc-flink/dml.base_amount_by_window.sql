-- Groups tbaseamount by its (start_date, end_date) window, carrying every base
-- amount that shares that window as an array. Plain deterministic GROUP BY --
-- no wall-clock function -- so it stays correct across restarts/replays.

INSERT INTO base_amount_by_window
SELECT
    ta.OBJECT_GUID,
    ta.start_date,
    ta.end_date,
    ARRAY_AGG(
        ROW(ta.GUID, ta.OBJECT_TYPE, ta.PRICE_LIST_GUID, ta.QUANTITY, ta.LIST, ta.SALE)
    ) AS amounts
FROM heartbeat hb
INNER JOIN tbaseamount ta
    ON  hb.tick_ts >= ta.start_date
    AND hb.tick_ts <  ta.end_date
GROUP BY ta.OBJECT_GUID, ta.start_date, ta.end_date;
