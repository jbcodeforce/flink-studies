# Wiki Index

> Content catalog. Every wiki page listed under its type with a one-line summary.
> Read this first to find relevant pages for any query.
> Last updated: 2026-05-23 | Total pages: 17

## Entities

- [[apache-flink]] — Open-source stream processing framework; distributed, fault-tolerant, unified batch+streaming
- [[confluent-cloud-for-flink]] — Fully managed Flink service; maps SQL constructs to environments/clusters/topics; CFU-based scaling
- [[confluent-platform-for-flink]] — Self-managed, on-premise Flink variant; user-provided infrastructure
- [[debezium]] — Open-source CDC platform; captures database changes for Kafka topics; emits retract events for CDC
- [[schema-registry]] — Stores schemas for Kafka topics; enables Avro/Protobuf serialization with Flink SQL tables

## Concepts

- [[changelog-mode]] — Three modes (append, upsert, retract) controlling how changes propagate through pipelines
- [[create-table]] — DDL operation for defining table metadata, partitioning, sinks, and source configurations
- [[ctas]] — Create Table As Select: creates a table and populates it in one statement
- [[flink-faker]] — Synthetic data generator connector bridging Flink SQL with DataFaker library
- [[flink-sql]] — ANSI-standard SQL interface for streaming pipelines via Table API
- [[kafka-connector]] — Primary data source/sink connector for Kafka topics with format, schema registry, and startup options
- [[kafka-partitioning]] — How data is distributed across Kafka topic partitions; DISTRIBUTED BY clause controls physical layout
- [[materialized-table]] — Managed streaming table with freshness guarantees, FULL or CONTINUOUS refresh
- [[medallion-architecture]] — Multi-layer pipeline (Bronze, Silver, Gold) with specific changelog modes per layer
- [[primary-key]] — Enables stateful deduplication and upsert semantics; NOT ENFORCED for performance optimization
- [[serialization-formats]] — Avro, Protobuf, JSON, CSV formats for message serialization performance tradeoffs
- [[view]] — Read-only SQL named query; shares namespace with tables; no physical storage
- [[watermark]] — Event-time progress definition; handles out-of-order events and late data

## Comparisons

## Queries

<!-- No queries filed -->
