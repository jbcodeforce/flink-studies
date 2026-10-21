-- Deterministic reproduction of the scenario for project 'P':
--   u1 assigned, t1 arrives, u2 assigned, t2 arrives, t3 arrives.
-- Project 'Q' adds a second partition-group to prove PARTITION BY isolates projects.
--
-- Rows are ordered by event_ts ASCENDING on purpose: the watermark allows only
-- 1s of lateness, so an out-of-order insert (e.g. Q's 10:00:03 row after P's
-- 10:00:20 row) would be dropped as late. Keep inserts in timestamp order.
--
-- The trailing 'FLUSH' events push the watermark PAST t3 (10:00:20) so the final
-- MATCH_RECOGNIZE match (P, u2, t3) can finalize and emit. Without them, event-time
-- CEP has no event after t3 to advance the watermark, so that match never appears.
-- 'FLUSH' is neither 'USER' nor 'TASK', so it is filtered out of all three queries.
INSERT INTO project_events (project_id, event_type, entity_id, event_ts) VALUES
  ('P', 'USER',  'u1', TIMESTAMP '2026-01-01 10:00:00'),
  ('Q', 'USER',  'u9', TIMESTAMP '2026-01-01 10:00:03'),
  ('P', 'TASK',  't1', TIMESTAMP '2026-01-01 10:00:05'),
  ('Q', 'TASK',  't9', TIMESTAMP '2026-01-01 10:00:08'),
  ('P', 'USER',  'u2', TIMESTAMP '2026-01-01 10:00:10'),
  ('P', 'TASK',  't2', TIMESTAMP '2026-01-01 10:00:15'),
  ('P', 'TASK',  't3', TIMESTAMP '2026-01-01 10:00:20'),
  ('P', 'FLUSH', '-',  TIMESTAMP '2026-01-01 10:05:00'),
  ('Q', 'FLUSH', '-',  TIMESTAMP '2026-01-01 10:05:00');
