   insert INTO
   last_expected_ts_package_events
   SELECT package_id, event_ts, status, expected_ts, event_type, payload
   FROM (
   SELECT *,
      LAG(expected_ts) OVER (PARTITION BY package_id ORDER BY event_ts) AS prev_expected_ts
   FROM package_events
   )
   WHERE prev_expected_ts IS NULL OR expected_ts <> prev_expected_ts