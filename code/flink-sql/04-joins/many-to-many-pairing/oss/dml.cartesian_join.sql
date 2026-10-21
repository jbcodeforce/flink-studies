-- APPROACH 3 — plain regular join: literal many-to-many (cartesian product).
--
-- Every USER crossed with every TASK sharing the project. For project 'P' with
-- users {u1,u2} and tasks {t1,t2,t3} it emits all 6 combinations as +I rows:
--   (u1,t1) (u1,t2) (u1,t3) (u2,t1) (u2,t2) (u2,t3)
-- CAUTION: a regular join keeps both input sides in state indefinitely; on
-- unbounded streams bound it with an interval/temporal join or state TTL.
SELECT
  u.project_id,
  u.entity_id AS user_id,
  t.entity_id AS task_id
FROM       (SELECT project_id, entity_id FROM project_events WHERE event_type = 'USER') AS u
INNER JOIN (SELECT project_id, entity_id FROM project_events WHERE event_type = 'TASK') AS t
  ON u.project_id = t.project_id;
