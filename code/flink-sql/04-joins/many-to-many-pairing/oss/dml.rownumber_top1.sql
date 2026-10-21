-- APPROACH 2 — ROW_NUMBER top-1 dedup: UPDATING changelog, one row PER KEY.
--
-- Keyed by project_id (the PARTITION BY column), so each project holds exactly
-- ONE row. A new task does not add a row — it RETRACTS the old winner and emits
-- the new one. In tableau result-mode watch the op column:
--   +I (P, t1) ; -U (P, t1) +U (P, t2) ; -U (P, t2) +U (P, t3)
-- This is the "update" behavior. It is mutually exclusive with keeping many
-- pairs per project: top-1 dedup is defined to keep one.
SELECT project_id, entity_id AS latest_task, event_ts
FROM (
  SELECT
    project_id,
    entity_id,
    event_ts,
    ROW_NUMBER() OVER (PARTITION BY project_id ORDER BY event_ts DESC) AS rn
  FROM project_events
  WHERE event_type = 'TASK'
)
WHERE rn = 1;
