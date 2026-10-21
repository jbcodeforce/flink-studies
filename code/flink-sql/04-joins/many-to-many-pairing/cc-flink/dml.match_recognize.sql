-- APPROACH 3 — MATCH_RECOGNIZE (CEP): append-only sequential pairing, no UDF.
--
-- Pattern: one USER, then zero-or-more "middle" TASK events, then a final TASK.
-- Flink SQL only supports ONE ROW PER MATCH (there is NO ALL ROWS PER MATCH), so
-- a match spanning several tasks collapses to one row; TEND (the last task) is the
-- one reported. The earlier tasks land in TMID and are folded away.
--
--   match 1 = (u1, TMID=[],   TEND=t1)      -> (P, u1, t1)
--   match 2 = (u2, TMID=[t2], TEND=t3)      -> (P, u2, t3)   <- t2 folded into TMID
--
-- Both rows are independent +I (INSERT) events. (P,u2,t3) is NOT an update to
-- (P,u1,t1): each MATCH has its own identity, with no GROUP BY key to collide on.
--
-- NOTE: the pattern must NOT end in a greedy quantifier (`T+`/`T*`) -- Flink
-- rejects that. Ending on the simple variable TEND is the required form; greedy
-- TMID* is fine because it is not the last element.
SELECT *
FROM project_events
MATCH_RECOGNIZE (
  PARTITION BY project_id
  ORDER BY event_ts                    -- order by the event-time attribute, ascending
  MEASURES
    U.entity_id          AS user_id,
    TEND.entity_id       AS task_id,    -- the task this match reports
    FIRST(TMID.entity_id) AS folded_first_task,  -- earlier task folded in (NULL if none)
    TEND.event_ts        AS paired_at
  ONE ROW PER MATCH
  AFTER MATCH SKIP PAST LAST ROW
  PATTERN (U TMID* TEND)
  DEFINE
    U    AS U.event_type    = 'USER',
    TMID AS TMID.event_type = 'TASK',
    TEND AS TEND.event_type = 'TASK'
) AS m;
