---
title: CREATE TABLE (DDL)
created: 2026-05-23
updated: 2026-05-23
type: concept
tags: [sql, ddl]
sources: [raw/articles/flink-sql-ddl-best-practices.md]
confidence: high
---

# CREATE TABLE (DDL)

## Overview
CREATE TABLE is the primary DDL operation in Flink SQL for defining table metadata. It declares columns, types, partitioning, and source/sink configurations. Tables registered via CREATE TABLE can serve as both [[table source|sources]] and [[table sink|sinks]].

## Basic Syntax
```sql
CREATE TABLE table_name (
    column_defs,
    PRIMARY KEY(key_col) NOT ENFORCED
) DISTRIBUTED BY (key_col) INTO n BUCKETS
WITH (connector_options);
```

## Key Components

### Column Definitions
- Must include column names and types
- [[primary-key]] columns must be NOT NULL
- [[create-table]] columns like `$rowtime` for event-time semantics
- [[create-table]] columns for Kafka headers, offsets, timestamps

### Partitioning
- `DISTRIBUTED BY (key) INTO N BUCKETS` controls Kafka topic partitions
- [[kafka-partitioning]] determines physical data layout
- Kafka-level partitioning, independent of Flink's [[primary-key]]

### WITH Options
- `connector`: kafka, filesystem, faker, datagen, jdbc, etc.
- `topic`: target Kafka topic name
- `properties.bootstrap.servers`: broker connection info
- `scan.startup.mode`: earliest-offset, latest-offset, timestamp, group-offsets
- `key.format` / `value.format`: avro-confluent, json, csv, etc.
- `changelog.mode`: append, upsert, retract

## Special Forms

### CTAS (Create Table As Select)
Creates a table and populates it in one statement via [[ctas]].

### MATERIALIZED TABLE
[[materialized-table]] provides data freshness guarantees with FULL or CONTINUOUS refresh modes.

### Views
[[view]] is read-only; shares namespace with tables in Flink.

## Best Practices
- Use `NOT ENFORCED` primary keys for performance
- Match [[primary-key]] to [[kafka-partitioning]] for [[changelog-mode]] workloads
- Set appropriate [[watermark]] strategies for late events
- Use `DESCRIBE EXTENDED` to verify table configuration
- Use `EXPLAIN` to verify query semantics before execution

## Related
- [[create-table]] for modifying existing table metadata
- [[kafka-connector]] topic concepts (cleanup.policy, partitions, retention)
- [[schema-registry]] integration for Avro/Protobuf
