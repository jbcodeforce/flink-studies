---
title: Debezium
created: 2026-05-23
updated: 2026-05-23
type: entity
tags: [connector, open-source]
sources: [raw/articles/flink-sql-ddl-best-practices.md]
confidence: high
---

# Debezium

## Overview
Debezium is an open-source CDC (Change Data Capture) platform that captures database changes and replays them to [[kafka-connector]] topics. When ingesting [[Debezium]] data into [[flink-sql]], the connector emits retract changelog events (+I, -D) corresponding to INSERT and DELETE operations.

## Schema Format
Debezium-avro registry schema includes:
- `before`: row state before the change
- `after`: row state after the change
- `op`: change type (c=create, u=update, d=delete, r=read)
- `source`: database and table metadata

## Flink SQL Integration

### Raw Table (Debezium Format)
```sql
CREATE TABLE raw_orders (
    order_id STRING,
    ...
) WITH (
    'connector' = 'kafka',
    'topic' = 'dbserver1.inventory.orders',
    'value.format' = 'avro-debezium-registry',
    'value.avro-confluent.url' = 'http://schema-registry:8081'
);
```

### Changelog Mode Implications
- Debezium sources use `changelog.mode = 'retract'` as default
- This maps to upsert key semantics in Flink
- DELETE events become retract (-D) messages
- INSERT/UPDATE events become upsert (+I) messages

## Medallion Architecture
In a [[medallion-architecture]], raw Debezium tables (Bronze layer) use:
- `cleanup.policy = 'delete'` on the source topic
- `changelog.mode = 'retract'` for CDC semantics
- `value.format = 'avro-debezium-registry'` for schema compatibility

## Related
- [[schema-registry]] for Avro schema management
- [[debezium]] integration patterns
- [[kafka-connector]] topic configuration
- [[schema-registry]] across layers
