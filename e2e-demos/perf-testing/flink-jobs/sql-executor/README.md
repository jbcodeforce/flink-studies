# SqlExecutor-Style Job (Table API + SQL)

Flink job that uses the Table API and executes SQL statements from a file. Pattern aligned with Confluent cp-flink-labs SqlExecutor: create a TableEnvironment, execute DDL (e.g. Kafka source/sink tables), then DML (e.g. INSERT INTO ... SELECT).

## Role in Perf Assessment

- Measures throughput and latency for a Table API + SQL pipeline reading from Kafka and writing to a sink.
- Same input topic/schema as the producer in `../../producer/`.

## Implementation Outline

- Entry point: main class that accepts a SQL script path (or resource).
- Parse and execute statements in order; handle `SET` and comments if needed (see `code/flink-java/sql-runner` in this repo for a reference).
- Use Kafka table descriptors (or Flink Kafka connector) for source and sink; align key/value format (JSON, Avro) with the producer.
- Build as a standard Flink application JAR for `flink run` or deployment to Confluent Platform / Confluent Cloud for Flink.

## SQL Script

- DDL: CREATE TABLE for Kafka source (topic, format, schema).
- DDL: CREATE TABLE for sink (topic or print).
- DML: INSERT INTO sink_table SELECT ... FROM source_table (with optional filters, aggregations, windows).

## Running

- Set Kafka bootstrap (and Schema Registry if used) via config or env.
- Run with: path to SQL script; ensure topic names match those used by `../../producer/` and `../../scripts/` topic creation.
