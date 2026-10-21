-- APPROACH 1 — MATCH_RECOGNIZE (CEP): append-only sequential pairing, no UDF.
--
-- One USER immediately followed by one TASK (two distinct, NON-overlapping
-- variables). Each match is one (user, task) pair emitted as an independent +I:
--
--   (P, u1, t1) ; (P, u2, t2) ; (Q, u9, t9)
--
-- t3 is an orphan task (no new USER before it in the sequence) and is NOT emitted:
-- CEP pairs by ORDER, so an unmatched event is dropped (unlike a join). Each row is
-- a new INSERT, never an update -- the contrast with Approach 2 (ROW_NUMBER top-1).
--
-- WHY NOT `PATTERN (U TMID* TEND)` (to fold t2+t3 into one (u2,t3) row): TMID and
-- TEND would both be event_type='TASK' -- two consecutive variables matching the
-- SAME rows. Flink warns against overlapping consecutive variables; here greedy
-- TMID* starves the mandatory TEND and the pattern matches NOTHING. Keep them distinct.
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
  AFTER MATCH SKIP PAST LAST ROW
  PATTERN (U T)
  DEFINE
    U AS U.event_type = 'USER',
    T AS T.event_type = 'TASK'
) AS m;
