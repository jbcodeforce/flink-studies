---
title: Medallion Architecture
created: 2026-05-23
updated: 2026-05-23
type: concept
tags: [architecture, streaming]
sources: [raw/articles/flink-sql-ddl-best-practices.md]
confidence: medium
---

# Medallion Architecture

## Overview
The [[medallion-architecture]] (also called the "multi-hop" or "delta" architecture) structures streaming data pipelines into three layers: Bronze (raw), Silver (intermediate), and Gold (sink). Each layer has specific objectives and [[changelog-mode]] configurations.

## Architecture Layers

| Layer | Table Type | Goals | Changelog Mode |
|-------|-----------|-------|---------------|
| **Bronze (Raw)** | Non-Debezium format | Ingest raw CDC/outbox data | append |
| **Bronze (Raw)** | Debezium format | CDC with delete semantics | retract |
| **Silver (Sources)** | Deduplicated | Keep last record per key | upsert |
| **Silver (Intermediate)** | Enrichment | Transform, join, enrich | upsert |
| **Gold (Sink)** | Facts, Dimensions | Star schema elements | retract or upsert |

## CDC Source Configuration
```sql
-- Non-debezium raw
cleanup.policy = 'delete', changelog.mode = 'append', value.format = 'avro-registry'

-- Debezium raw
cleanup.policy = 'delete', changelog.mode = 'retract', value.format = 'avro-debezium-registry'
```

## Sink Configuration
```sql
-- For star schema sinks
cleanup.policy = 'compact', changelog.mode = 'retract' or 'upsert'
```

## Key Principles
1. Each hop cleans and enriches the data further
2. Bronze preserves original data shape
3. Silver deduplicates and validates
4. Gold optimizes for query patterns
5. Cleanup policies control Kafka retention

## Flink Implementation
- Each layer is a [[CREATE TABLE]] definition
- Data flows via [[insert-into|create-table]] statements
- [[changelog-mode]] transitions between layers
- [[materialized-table]] for managed intermediate layers

## Related
- [[changelog-mode]] for each layer's output semantics
- [[kafka-connector]] topic configuration
- [[schema-registry]] across layers
- [[primary-key]] implications for CDC
