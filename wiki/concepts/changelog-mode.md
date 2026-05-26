---
title: Changelog Mode
created: 2026-05-23
updated: 2026-05-23
type: concept
tags: [sql, streaming]
sources: [raw/articles/flink-sql-ddl-best-practices.md]
confidence: high
---

# Changelog Mode

## Overview
Changelog mode determines how a Flink SQL table emits changes to downstream consumers or persists them to a sink. The three modes are: [[changelog-mode]], [[changelog-mode]], and [[changelog-mode]].

## Changelog Modes

| Mode | Behavior | Use Case |
|------|----------|----------|
| **append** | Only inserts; old rows are never removed | CDC raw sources, IoT event logs |
| **upsert** | Inserts new rows; updates existing rows by primary key | Deduplicated tables, dimension enrichment |
| **retract** | Inserts (+I) and deletes (-D) messages | Debezium sources with delete events |

## Bucket Key Constraints

| Mode | Bucket Key Requirement |
|------|----------------------|
| **upsert** | Must equal primary key |
| **append/retract** | Can be a subset of primary key |

## CDC Implications
In a [[medallion-architecture]], each layer uses appropriate changelog modes:

| Layer | Changelog Mode | Purpose |
|-------|---------------|---------|
| Raw (non-Debezium) | append | Incoming events |
| Raw (Debezium) | retract | CDC with deletes |
| Sources | upsert | Deduplication |
| Intermediates | upsert | Enrichment + transformation |
| Sink (facts/dimensions) | retract or upsert | Star schema outputs |

## Related
- [[primary-key]] for deduplication semantics
- [[materialized-table]] for managed refresh modes
- [[schema-registry]] and Avro integration
- [[kafka-connector]] connector configuration
