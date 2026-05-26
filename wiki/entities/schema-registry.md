---
title: Schema Registry
created: 2026-05-23
updated: 2026-05-23
type: entity
tags: [tool, schema]
sources: [raw/articles/flink-sql-ddl-best-practices.md]
confidence: high
---

# Schema Registry

## Overview
{{Schema Registry}} (Avro Schema Registry) is a service that stores a schema for each subject (typically Kafka topic name). {{Flink}} SQL tables use it to serialize/deserialize [[schema-registry]]-formatted Kafka messages.

## Key Concepts
- **Subject**: Schema identifier (typically `<topic>-value` or `<topic>-key`)
- **Schema formats**: Avro, Protobuf, JSON Schema
- **Compatibility**: Full, Backward, Forward compatibility modes
- **Evolution**: Schema evolution managed through compatibility rules

## Flink SQL Integration
```sql
-- Avro with Confluent Schema Registry
'connector' = 'kafka',
'value.format' = 'avro-confluent',
'value.avro-confluent.url' = 'http://schema-registry:8081',
'key.format' = 'avro-confluent',
'key.avro-confluent.url' = 'http://schema-registry:8081'

-- Debezium avro
'value.format' = 'avro-debezium-registry',
'value.avro-debezium.url' = 'http://schema-registry:8081'
```

## Schema Auto-Generation
In Confluent Cloud, table creation automatically generates:
- Key schema from primary key declaration
- Value schema from column definitions
- Doc comments from `COMMENT` clauses

In Flink OSS with Schema Registry:
- Schema must exist before table creation
- Use `extract_sql_from_avro.py` to build SQL from registry schemas
- Schema registry URL must be accessible from Flink cluster

## Related
- [[debezium]] / [[Debezium]] schema evolution
- [[schema-registry]] principles
- [[kafka-connector]] / [[confluent-cloud-for-flink]] integration
- [[schema-registry]] compatibility modes
