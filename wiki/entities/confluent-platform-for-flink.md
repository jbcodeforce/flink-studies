---
title: Confluent Platform for Flink
created: 2026-05-23
updated: 2026-05-23
type: entity
tags: [deployment, confluent-platform-for-flink]
sources: [raw/articles/flink-sql-ddl-best-practices.md]
confidence: medium
---

# Confluent Platform for Flink

## Overview
Confluent Platform for Flink is the self-managed, on-premise/open-source variant of Confluent's Flink streaming service. It runs on top of a user-provided Kubernetes or VM infrastructure with fully managed Confluent Platform components (Kafka, Schema Registry, etc.).

## Deployment Architecture
- Runs on [[confluent-platform-for-flink]] (official operator) or standalone servers
- User manages Kubernetes cluster, Kafka cluster, and Schema Registry
- Flink cluster is provisioned as part of Confluent Platform

## Key Differences from Confluent Cloud
| Aspect | Confluent Cloud | Confluent Platform |
|--------|----------------|-------------------|
| Management | Fully managed | User-managed |
| Scaling | CFU-based (auto) | Manual (resources) |
| Schema Registry | Integrated | User-provided |
| Kafka topics | Auto-created with tables | Pre-created topics |
| Metadata | Confluent-owned | User-defined catalogs |

## DDL Compatibility
Table DDL statements are shared with open-source Flink OSS. The `WITH` clause specifies:
- `connector`: kafka
- `topic`: target Kafka topic
- `properties.bootstrap.servers`: broker list
- `properties.group.id`: consumer group
- `scan.startup.mode`: earliest-offset, latest-offset, etc.
- `key.format` / `value.format`: serialization format

## Use Cases
- Organizations requiring on-premise deployment
- Custom infrastructure management
- Cost optimization at large scale
- Compliance requirements (data residency)

## Related
- [[confluent-cloud-for-flink]] for cloud variant
- [[kafka-connector]] connector configuration
- [[schema-registry]] for Avro/Protobuf schemas
