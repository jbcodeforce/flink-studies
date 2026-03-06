-- Validate: sink has one row per (package_id, expected_ts) from the test insert.
-- Expected: (pkg_x, 10:00, 11:30), (pkg_x, 10:10, 12:00), (pkg_y, 10:15, 11:30).

WITH expected AS (
  SELECT 'pkg_x' AS package_id, TIMESTAMP '2025-03-04 10:00:00' AS event_ts, 'ok' AS status, TIMESTAMP '2025-03-04 11:30:00' AS expected_ts, 'a' AS payload, 1 AS slot_key
  UNION ALL
  SELECT 'pkg_x', TIMESTAMP '2025-03-04 10:10:00', 'ok', TIMESTAMP '2025-03-04 12:00:00', 'c', 1
  UNION ALL
  SELECT 'pkg_y', TIMESTAMP '2025-03-04 10:15:00', 'ok', TIMESTAMP '2025-03-04 11:30:00', 'd', 1
),
actual AS (
  SELECT package_id, event_ts, status, expected_ts, payload, slot_key
  FROM package_events_on_expected_ts_sink_read
),
check_result AS (
  SELECT
    e.package_id,
    e.expected_ts,
    CASE
      WHEN a.package_id IS NULL THEN 'FAIL'
      WHEN a.event_ts <> e.event_ts THEN 'FAIL'
      WHEN a.status <> e.status THEN 'FAIL'
      WHEN a.expected_ts <> e.expected_ts THEN 'FAIL'
      WHEN (a.payload IS NULL AND e.payload IS NOT NULL) OR (a.payload IS NOT NULL AND e.payload IS NULL) THEN 'FAIL'
      WHEN a.payload IS NOT NULL AND e.payload IS NOT NULL AND a.payload <> e.payload THEN 'FAIL'
      WHEN a.slot_key <> e.slot_key THEN 'FAIL'
      ELSE 'PASS'
    END AS result
  FROM expected e
  LEFT JOIN actual a ON e.package_id = a.package_id AND e.expected_ts = a.expected_ts
),
overall AS (
  SELECT
    (SELECT COUNT(*) FROM expected) AS expected_count,
    (SELECT COUNT(*) FROM actual) AS actual_count,
    (SELECT COUNT(*) FROM check_result WHERE result = 'PASS') AS pass_count
)
SELECT
  CASE
    WHEN expected_count = actual_count AND expected_count = pass_count THEN 'PASS'
    ELSE 'FAIL'
  END AS test_result,
  expected_count,
  actual_count,
  pass_count
FROM overall;
