# Flink Jobs for Performance Assessment

Each subfolder contains one Flink job variant used to assess throughput and latency in the e2e perf-testing pipeline. All jobs consume from the same Kafka topics produced by `../producer/` and write to a configured sink (Kafka topic or print).

| Subfolder       | Type              | Use case                                      |
|-----------------|-------------------|-----------------------------------------------|
| `sql-executor/` | Table API + SQL   | SqlExecutor-style: execute DDL/DML from file  |
| `datastream/`   | DataStream API    | Optional comparison with DataStream pipeline  |
| `flink-sql/`    | Flink SQL only    | Optional SQL-only deployment (e.g. SQL gateway)|

Ensure each job’s source topic and schema match the producer output. See parent [README](../README.md) for the overall run procedure and metrics.
