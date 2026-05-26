# Wiki Log

> Chronological record of all wiki actions. Append-only.
> Format: `## [YYYY-MM-DD] action | subject`
> Actions: ingest, update, query, lint, create, archive, delete
> When this file exceeds 500 entries, rotate: rename to log-YYYY.md, start fresh.

## [2026-05-23] create | Wiki initialized
- Domain: Apache Flink streaming data infrastructure
- Structure created with SCHEMA.md, index.md, log.md

## [2026-05-23] ingest | Flink SQL DDL Best Practices
- Source: raw/articles/flink-sql-ddl-best-practices.md (24357 bytes)
- Description: Comprehensive guide on CREATE TABLE DDL, connectors, CDC patterns, watermarking, medallion architecture
- Pages created (17):
  - [[entities/apache-flink]] — Overview of Apache Flink framework and deployment options
  - [[entities/confluent-cloud-for-flink]] — Confluent Cloud managed Flink service
  - [[entities/confluent-platform-for-flink]] — On-premise Confluent Platform Flink variant
  - [[entities/debezium]] — CDC platform for database change capture
  - [[entities/schema-registry]] — Schema management service for Avro/Protobuf
  - [[concepts/flink-sql]] — ANSI-standard SQL streaming interface
  - [[concepts/create-table]] — DDL CREATE TABLE syntax and options
  - [[concepts/changelog-mode]] — Append, upsert, retract change semantics
  - [[concepts/watermark]] — Event-time progress and late event handling
  - [[concepts/primary-key]] — Primary key for dedup and state management
  - [[concepts/materialized-table]] — Managed streaming table with freshness guarantees
  - [[concepts/medallion-architecture]] — Bronze/Silver/Gold pipeline layers
  - [[concepts/ctas]] — Create Table As Select pattern
  - [[concepts/kafka-connector]] — Kafka connector configuration reference
  - [[concepts/flink-faker]] — Synthetic data generation tutorial
  - [[concepts/view]] — Read-only SQL views
  - [[concepts/kafka-partitioning]] — Partition distribution and performance tuning
  - [[concepts/serialization-formats]] — Avro/Protobuf/JSON/CSV comparison

## [2026-05-23] update | index.md (17 pages cataloged)
