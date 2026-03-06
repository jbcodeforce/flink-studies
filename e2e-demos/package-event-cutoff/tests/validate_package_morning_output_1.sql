-- Validate test 1: expect (pkg_a, received, 10:00, delivered) and (pkg_b, proactive_no_event, 11:30, null).
-- Query package_morning_output_read and compare to expected; return PASS or FAIL.

WITH expected AS (
  SELECT 'pkg_a' AS package_id, 'received' AS event_type, TIMESTAMP '2025-03-04 10:00:00' AS event_ts, 'delivered' AS payload
  UNION ALL
  SELECT 'pkg_b', 'proactive_no_event', TIMESTAMP '2025-03-04 11:30:00', CAST(NULL AS STRING)
),
actual AS (
  SELECT package_id, event_type, event_ts, payload
  FROM package_morning_output_read
),
check_result AS (
  SELECT
    e.package_id,
    e.event_type,
    CASE
      WHEN a.package_id IS NULL THEN 'FAIL'
      WHEN a.event_type <> e.event_type THEN 'FAIL'
      WHEN a.event_ts <> e.event_ts THEN 'FAIL'
      WHEN (a.payload IS NULL AND e.payload IS NOT NULL) OR (a.payload IS NOT NULL AND e.payload IS NULL) THEN 'FAIL'
      WHEN a.payload IS NOT NULL AND e.payload IS NOT NULL AND a.payload <> e.payload THEN 'FAIL'
      ELSE 'PASS'
    END AS result
  FROM expected e
  LEFT JOIN actual a ON e.package_id = a.package_id AND e.event_type = a.event_type
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
