---
title: Kafka Connector
created: 2026-05-23
updated: 2026-05-23
type: concept
tags: [connector, k8s]
sources: [raw/articles/flink-sql-ddl-best-practices.md]
confidence: high
---

# Kafka Connector

## Overview
The [[kafka-connector]] connector is the primary data source/sink for streaming data in Flink. It enables Flink SQL tables to read from and write to Kafka topics.

## Configuration Pattern
```sql
CREATE TABLE stream_table (
    col1 STRING,
    col2 INT,
    PRIMARY KEY (col1) NOT ENFORCED
) WITH (
    'connector' = 'kafka',
    'topic' = 'topic_name',
    'properties.bootstrap.servers' = 'broker:9092',
    'properties.group.id' = 'flink-group',
    'scan.startup.mode' = 'earliest-offset',
    'key.format' = 'avro-confluent',
    'value.format' = 'avro-confluent',
    'value.avro-confluent.url' = 'http://schema-registry:8081'
);
```

## Key Properties

### Connection
- `properties.bootstrap.servers`: Kafka broker list
- `properties.group.id`: Consumer group ID
- `scan.startup.mode`: Startup position (earliest, latest, timestamp, group-offsets)

### Format
- `key.format`: avro-confluent, json, csv, raw, protobuf
- `value.format`: avro-confluent, json, csv, avro-debezium-registry
- key.fields / value.fields-include

### Schema Registry
- `value.avro-confluent.url`: Schema Registry endpoint
- `value.protobuf.schema.registry.url`: Protobuf registry endpoint

## Kafka-Specific Options
- `kafka.consumer.isolation-level`: read-uncommitted (at-least-once), read-committed (exactly-once)
- `kafka.retention.time`: Custom topic retention override
- `key.format = 'raw'`: Bypass key schema generation

## Flink OSS vs Confluent Cloud Differences
| Aspect | Flink OSS | Confluent Cloud |
|--------|-----------|----------------|
| Metadata | User-defined | Pre-created for each topic |
| Partitioning | Distributed BY clause | Auto-generated from primary key |
| Schema | Manual/Registry | Auto from topic |

## Performance Considerations
- 18 MB/s partition bottleneck per partition
- Avro serialization is slower than Protobuf
- Key skew: distribute by multiple fields to improve parallelism
- 5 partitions feed 1 CFU in Confluent Cloud

## Related
- [[schema-registry]] for Avro managed schemas
- [[changelog-mode]] for change semantics
- [[kafka-partitioning]] for data distribution
- [[watermark]] for event-time handling
