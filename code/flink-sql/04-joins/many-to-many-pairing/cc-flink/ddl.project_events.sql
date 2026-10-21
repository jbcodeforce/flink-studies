-- Single append stream carrying BOTH entity types that share the join key.
-- USER events carry a user id in entity_id; TASK events carry a task id.
-- A unified stream is required because MATCH_RECOGNIZE pattern-matches over one
-- partitioned, time-ordered stream (it cannot span two separate tables).
CREATE TABLE project_events (
  project_id STRING      NOT NULL,   -- the shared key
  event_type STRING      NOT NULL,   -- 'USER' or 'TASK'
  entity_id  STRING      NOT NULL,   -- user id (U*) when USER, task id (T*) when TASK
  event_ts   TIMESTAMP(3) NOT NULL,  -- event time; drives MATCH_RECOGNIZE ORDER BY
  WATERMARK FOR event_ts AS event_ts - INTERVAL '1' SECOND
)
-- Single partition is essential for this demo: with CC's default multi-partition
-- topic, the empty partitions keep the source watermark at -infinity, so event-time
-- MATCH_RECOGNIZE never finalizes a match and returns ZERO rows. One bucket = one
-- partition = a watermark that actually advances. (If `DISTRIBUTED INTO` is
-- rejected, use `DISTRIBUTED BY (project_id) INTO 1 BUCKETS`.)
DISTRIBUTED INTO 1 BUCKETS
WITH (
  'changelog.mode' = 'append',
);
