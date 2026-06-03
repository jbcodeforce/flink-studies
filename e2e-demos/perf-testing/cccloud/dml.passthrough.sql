-- Passthrough pipeline for perf testing on Confluent Cloud for Flink.
-- Deploy after ddl.perf_source.sql and ddl.perf_sink.sql.

INSERT INTO perf_sink
SELECT id, event_time, value, payload FROM perf_source;
