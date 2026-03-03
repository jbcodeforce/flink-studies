-- Passthrough: copy perf_source to perf_sink.
-- Run after ddl_source.sql and ddl_sink.sql.

INSERT INTO perf_sink SELECT id, event_time, value, payload FROM perf_source;
