---
title: Serialization Formats
created: 2026-05-23
updated: 2026-05-23
type: concept
tags: [schema, performance]
sources: [raw/articles/flink-sql-ddl-best-practices.md]
confidence: medium
---

# Serialization Formats

## Overview
Flink SQL supports multiple serialization formats for Kafka message keys and values. Format choice affects [[serialization-formats]] and schema compatibility.

## Supported Formats

| Format | Type | Schema | Notes |
|--------|------|--------|-------|
| **Avro (Confluent)** | Value/Key | Avro Schema Registry | Default for CDC pipelines |
| **Avro Debezium Registry** | Value | Avro Schema Registry | CDC-specific with source metadata |
| **Protobuf** | Value/Key | Protobuf Schema Registry | Faster than Avro serialization |
| **JSON** | Value/Key | None (self-describing) | Human-readable, larger size |
| **CSV** | Value | None (schema required separately) | Simple tabular data |
| **Raw** | Key only | None | Bypass key schema generation |

## Performance Comparison
- **Protobuf**: Fastest serialization/deserialization
- **Avro**: Moderate performance, good schema support
- **JSON**: Slower, larger payload size
- **CSV**: Moderate, no native schema enforcement

## Format Selection Guide
- **CDC pipelines**: Avro Confluent or Debezium Registry
- **Internal microservices**: Protobuf for performance
- **Dashboard/visualization**: JSON for human readability
- **Batch processing**: CSV for simplicity

## Key Format Options
```sql
'key.format' = 'raw',                    -- No key schema
'key.format' = 'json',                   -- JSON key
'key.format' = 'avro-confluent',         -- Avro from registry
'key.format' = 'protobuf',               -- Protobuf from registry
```

## Value Format Options
```sql
'value.format' = 'avro-confluent',                   -- Avro from registry
'value.format' = 'avro-debezium-registry',           -- Debezium avro
'value.format' = 'protobuf',                         -- Protobuf
'value.format' = 'json',                             -- JSON
'value.format' = 'csv',                              -- CSV
```

## Related
- [[schema-registry]] for Avro managed schemas
- [[kafka-connector]] / [[Debezium]] schema evolution
- [[schema-registry]] compatibility modes
- [[serialization-formats]] tuning
