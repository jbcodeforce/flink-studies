# Flink SQL Only (Optional)

Pure Flink SQL deployment for environments where jobs are submitted as SQL (e.g. SQL gateway, Confluent Cloud for Flink SQL, or OSS Flink SQL client).

## Role in Perf Assessment

- Same logical pipeline as `../sql-executor/` but submitted as SQL only (no Java Table API driver).
- Use when assessing SQL-only submission path or managed Flink SQL services.

## Contents

- SQL files: DDL for Kafka source/sink tables and DML (e.g. INSERT INTO ... SELECT).
- Optional script or instructions to submit these statements to the target Flink SQL endpoint.
- Schema and topic names must match `../../producer/` and topic creation in `../../scripts/`.

## Running

- Submit DDL then DML via SQL gateway REST API, Flink SQL client, or platform UI.
- Ensure Kafka connectivity and catalog/database configuration point to the same topics as the producer.
