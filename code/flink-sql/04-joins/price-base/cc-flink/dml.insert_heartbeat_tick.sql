-- Advances the heartbeat by one tick. This is a bounded (one-shot) statement,
-- not a continuous query -- CURRENT_TIMESTAMP is safe to use here because it is
-- evaluated exactly once, at submission time, and baked into the row as a
-- genuinely new event. Run it repeatedly on an interval via an external
-- scheduler (cron, `watch`, a CI job, etc.) -- see README.md.
--
--   make deploy-heartbeat            # one tick

--- INSERT INTO heartbeat VALUES (1, CURRENT_TIMESTAMP);
INSERT INTO heartbeat VALUES (1, TO_TIMESTAMP_LTZ('2024-04-01 00:01:00'));