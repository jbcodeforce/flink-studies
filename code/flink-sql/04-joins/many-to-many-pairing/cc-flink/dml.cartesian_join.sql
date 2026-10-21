-- APPROACH 1 — plain regular join: literal many-to-many (cartesian product).
--
-- This is what "many-to-many" means to the SQL engine: every USER crossed with
-- every TASK that shares the project. For project 'P' with users {u1,u2} and
-- tasks {t1,t2,t3} it emits all 6 combinations as +I (append) rows:
--   (u1,t1) (u1,t2) (u1,t3) (u2,t1) (u2,t2) (u2,t3)
--
-- Use this when you genuinely want all pairings. CAUTION: a regular (non-windowed,
-- non-temporal) join keeps BOTH input sides in state indefinitely, so unbounded
-- streams grow state without limit. Bound it with an interval join, a temporal
-- join (see README recommendation), or state TTL in production.
SELECT
  u.project_id,
  u.entity_id AS user_id,
  t.entity_id AS task_id
FROM       (SELECT project_id, entity_id FROM project_events WHERE event_type = 'USER') AS u
INNER JOIN (SELECT project_id, entity_id FROM project_events WHERE event_type = 'TASK') AS t
  ON u.project_id = t.project_id;
