# Flink Jobs for Performance Assessment

All jobs target **Flink 2.2.0** and consume `perf-input` / write `perf-output` (see [../producer](../producer/)).

| Subfolder | API | Deploy |
|-----------|-----|--------|
| [sql-executor/](sql-executor/) | Table API + SQL file | `flink run`, OSS/CP K8s |
| [datastream/](datastream/) | DataStream Kafka connector | `flink run` |
| [flink-sql/](flink-sql/) | Raw SQL | SQL gateway / [../cccloud](../cccloud/) |

Build all: `../scripts/build-all.sh`
