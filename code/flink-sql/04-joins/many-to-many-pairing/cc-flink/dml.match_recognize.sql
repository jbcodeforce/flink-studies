-- APPROACH 3 — MATCH_RECOGNIZE (CEP): append-only sequential pairing, no UDF.
--
-- Pattern: one USER immediately followed by one TASK (two distinct, NON-overlapping
-- variables). Each match is one (user, task) pair, emitted as an independent +I:
--
--   (P, u1, t1)   u1 then its next task t1
--   (P, u2, t2)   u2 then its next task t2
--   (Q, u9, t9)
--
-- t3 is NOT emitted: it is an orphan task with no new USER before it in the
-- sequence. Unlike a join, CEP pairs by ORDER, so an unmatched event is dropped.
-- Each row is a new INSERT, never an update -- there is no GROUP BY key to collide
-- on. That is the contrast with Approach 2 (ROW_NUMBER top-1), which updates in place.

-- Idle timeout: on Confluent Cloud `sql.tables.scan.idle-timeout` defaults to 0
-- (OFF), so a caught-up source may not advance its watermark; set it so pending
-- matches flush. Run in the SAME workspace session, immediately before the query.
SET 'sql.tables.scan.idle-timeout' = '1 s';

SELECT *
FROM project_events
MATCH_RECOGNIZE (
  PARTITION BY project_id
  ORDER BY event_ts                 -- order by the event-time attribute, ascending
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
