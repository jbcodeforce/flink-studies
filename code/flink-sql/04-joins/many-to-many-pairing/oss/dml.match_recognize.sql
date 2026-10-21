-- APPROACH 1 — MATCH_RECOGNIZE (CEP): append-only sequential pairing, no UDF.
--
-- Pattern: one USER, then zero-or-more "middle" TASK events, then a final TASK.
-- Flink SQL only supports ONE ROW PER MATCH (no ALL ROWS PER MATCH), so a match
-- spanning several tasks collapses to one row; TEND (the last task) is reported
-- and the earlier tasks land in TMID (folded away).
--
--   match 1 = (u1, TMID=[],   TEND=t1)      -> (P, u1, t1)
--   match 2 = (u2, TMID=[t2], TEND=t3)      -> (P, u2, t3)   <- t2 folded into TMID
--
-- Both are independent +I (INSERT) rows: (P,u2,t3) is NOT an update to (P,u1,t1)
-- because each match has its own identity (no shared GROUP BY key).
--
-- NOTE: the pattern must NOT end in a greedy quantifier (`T+`/`T*`) -- Flink
-- rejects that. Ending on the simple variable TEND is the required form.
SELECT *
FROM project_events
MATCH_RECOGNIZE (
  PARTITION BY project_id
  ORDER BY event_ts
  MEASURES
    U.entity_id           AS user_id,
    TEND.entity_id        AS task_id,
    FIRST(TMID.entity_id) AS folded_first_task,
    TEND.event_ts         AS paired_at
  ONE ROW PER MATCH
  AFTER MATCH SKIP PAST LAST ROW
  PATTERN (U TMID* TEND)
  DEFINE
    U    AS U.event_type    = 'USER',
    TMID AS TMID.event_type = 'TASK',
    TEND AS TEND.event_type = 'TASK'
) AS m;
