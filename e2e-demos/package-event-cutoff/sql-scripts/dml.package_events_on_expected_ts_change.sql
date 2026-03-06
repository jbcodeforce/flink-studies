-- Emit package_events to sink only when expected_ts has changed for a given package_id.
-- Uses deduplication: one row per (package_id, expected_ts), keeping the first event by event_ts.

INSERT INTO last_expected_ts_package_events
with deduplicated_package_events as (
  SELECT package_id, event_ts, status, expected_ts, event_type, payload
  FROM (
    SELECT *,
      ROW_NUMBER() OVER (
        PARTITION BY package_id, expected_ts
        ORDER BY event_ts ASC
      ) AS row_num
    FROM package_events
  )
  WHERE row_num = 1
)
select * from deduplicated_package_events;