---
title: Confluent Cloud for Flink
created: 2026-05-23
updated: 2026-05-23
type: entity
tags: [deployment, confluent-platform-for-flink]
sources: [raw/articles/flink-sql-ddl-best-practices.md]
confidence: high
---

# Confluent Cloud for Flink

## Overview
Confluent Cloud for Flink is a fully managed Flink service that enables real-time stream processing with fully managed infrastructure. It maps Flink SQL constructs to Confluent's own terminology.

## Mapping from Flink to Confluent Cloud

| Flink Concept | Confluent Cloud Equivalent |
| --- | --- |
| Catalog / Database | Environment / Cluster / Namespace |
| Kafka Topic | Auto-managed via table creation |
| Schema Registry | Integrated schema management |

## Key Features
- Pre-created tables: One table per Kafka topic (automatic topic-table mapping)
- CFU-based scaling: Compute scaled by [Confluent Flink Units](#cfu-scaling)
- Managed schema: Automatic schema generation from table definitions
- Built-in topics: Topics auto-created when tables are written to

## Table Creation Specifics
- In Confluent Cloud, partition key will generate a key schema (unless `'key.format' = 'raw'`)
- If destination topic has no partition key, CC Flink SQL writes data to whatever partitioning was used at the end of the query
- If last operation is `GROUP BY foo` or `JOIN ON A.foo = B.foo`, output records are partitioned on `foo` values
- The `foo` partitioning is preserved, no re-partitioning needed
- Primary key + DISTRIBUTED BY clause to control topic partitioning

## Performance Metrics
- CFU ratio: 5 partitions feed 1 CFU
- CFU constraints: Each CFU has fixed memory and CPU limits
- Bottleneck: Serialization/deserialization (Avro is slower than Protobuf)
- Partition limit: 18 MB/s per partition

## Deployment Considerations
- Key skew: add more fields in distribution to improve parallelism
- Partition count affects CFU allocation
- Use `distributed by hash(key)` for data shuffling

## Related
- [[confluent-platform-for-flink]] for self-managed alternative
- [[kafka-connector|kafka-connector]] partitioning and [[watermark]] semantics
- [[schema-registry]] integration for Avro/Protobuf

## Confluent Platform for Flink

Confluent Platform for Flink is the self-managed, on-premise variant of Confluent Cloud for Flink. Key differences from Confluent Cloud:
- Catalog / database management is user-managed
- Table DDL syntax is shared with open-source Flink
- Infrastructure is user-provided (Kafka cluster, Schema Registry)
- `WITH` clause used extensively for connection details
