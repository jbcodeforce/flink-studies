# Dedup demo – OSS Flink

## Goal

Deduplicate product events from Kafka using Flink SQL (interactive or SQL CLI). Same business logic as [../cp-flink/](../cp-flink/) (Table API variant).

## Status

Ready. Use with OSS Flink (local or K8s). Producer: [../python-producer/](../python-producer/).

## Implementation approach

- **No IaC:** Run Flink SQL via CLI or SQL Gateway. Script: `flink-sql/run-flink-dedup.sh`.
- **Application logic:** DDL/DML in `flink-sql/flink-deduplication.sql`.

## How to run

From **demo root**: run [../python-producer/](../python-producer/) to generate events. Then from `oss-flink/flink-sql/`: run `./run-flink-dedup.sh` (or use SQL in Flink SQL client). See root [README.md](../README.md).
