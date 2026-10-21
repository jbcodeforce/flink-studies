-- Deterministic scenario for project 'P': u1, t1, u2, t2, t3.
-- Project 'Q' adds a second partition-group to prove PARTITION BY isolates projects.
-- Run this INSERT first (it writes to Kafka and the bounded job completes),
-- THEN run a dml.*.sql SELECT so 'latest-offset' includes these rows.
--
-- Rows are ordered by event_ts ASCENDING: the 1s watermark drops out-of-order rows,
-- so an earlier Q row inserted after a later P row would be lost. Keep ts order.
--
-- 'FLUSH' events push the watermark past t3 so the final MATCH_RECOGNIZE match
-- (P, u2, t3) emits. With 'scan.bounded.mode=latest-offset' EOF already emits a
-- final watermark, so FLUSH is belt-and-suspenders here; it also keeps the data
-- identical to the cc-flink variant. 'FLUSH' is filtered out of all three queries.
INSERT INTO project_events VALUES
  ('P', 'USER',  'u1', TIMESTAMP '2026-01-01 10:00:00'),
  ('Q', 'USER',  'u9', TIMESTAMP '2026-01-01 10:00:03'),
  ('P', 'TASK',  't1', TIMESTAMP '2026-01-01 10:00:05'),
  ('Q', 'TASK',  't9', TIMESTAMP '2026-01-01 10:00:08'),
  ('P', 'USER',  'u2', TIMESTAMP '2026-01-01 10:00:10'),
  ('P', 'TASK',  't2', TIMESTAMP '2026-01-01 10:00:15'),
  ('P', 'TASK',  't3', TIMESTAMP '2026-01-01 10:00:20'),
  ('P', 'FLUSH', '-',  TIMESTAMP '2026-01-01 10:05:00'),
  ('Q', 'FLUSH', '-',  TIMESTAMP '2026-01-01 10:05:00');
