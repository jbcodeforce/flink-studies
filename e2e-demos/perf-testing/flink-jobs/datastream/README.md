# DataStream Job (Optional)

Flink DataStream API job used to compare performance with the Table API + SQL pipeline in `../sql-executor/`.

## Role in Perf Assessment

- Consumes from the same Kafka topic(s) as the producer and sql-executor job.
- Measures throughput and latency for a DataStream pipeline (e.g. keyed aggregation, windowing).
- Enables comparison: DataStream vs Table API/SQL under the same load.

## Implementation Outline

- Use Kafka Source (Flink Kafka connector) with the same topic and deserialization as the SQL job’s source table.
- Example patterns: map/filter, keyBy + aggregation, tumbling/sliding windows.
- Sink: Kafka sink or other (e.g. print) for metrics; ensure serialization matches if writing to Kafka.

## Build and Run

- Standard Maven/Gradle Flink application; package as JAR and run via `flink run` or platform deployment.
- Configure bootstrap and topic names to match `../../producer/` and `../../scripts/`.
