-- APPROACH 3 — MATCH_RECOGNIZE (CEP): append-only sequential pairing, no UDF.
--
-- One USER immediately followed by one TASK (two distinct, NON-overlapping
-- variables). Each match is one (user, task) pair emitted as an independent +I:
--
--   (P, u1, t1) ; (P, u2, t3) ; (Q, u9, t9)
--
SELECT *
FROM project_events
MATCH_RECOGNIZE (
  PARTITION BY project_id
  ORDER BY event_ts
  MEASURES
    U.entity_id AS user_id,
    T.entity_id AS task_id,
    T.event_ts  AS paired_at
  ONE ROW PER MATCH
  PATTERN (U T+ NEXTU)                     -- distinct variables, ends on simple var T
  DEFINE
    U AS U.event_type = 'USER',
    T AS T.event_type = 'TASK',
   NEXTU as NEXTU.event_type = 'USER' or NEXTU.event_type = 'FLUSH'
) AS m;
