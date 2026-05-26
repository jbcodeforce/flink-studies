---
title: Kafka Partitioning
created: 2026-05-23
updated: 2026-05-23
type: concept
tags: [connector, performance]
sources: [raw/articles/flink-sql-ddl-best-practices.md]
confidence: high
---

# Kafka Partitioning

## Overview
Kafka partitioning in Flink SQL determines how data is distributed across [[Kafka|kafka-connector]] topic partitions. It is distinct from Flink's [[primary-key]] concept.

## Distribution Clause
```sql
CREATE TABLE table_name (
    col1 STRING PRIMARY KEY NOT ENFORCED,
    col2 INT
) DISTRIBUTED BY (col1) INTO 4 BUCKETS;
```

- `DISTRIBUTED BY (col1)`: Specifies which column(s) determine partition key
- `INTO n BUCKETS`: Number of Kafka topic partitions

## Primary Key vs Partition Key
| Aspect | Primary Key | Partition Key |
|--------|------------|---------------|
| Purpose | Dedup state key, change semantic | Physical Kafka layout |
| Declaration | `PRIMARY KEY NOT ENFORCED` | `DISTRIBUTED BY ...` |
| Scope | Flink state management | Kafka physical partitioning |
| Enforced? | No (optimization) | No (metadata only) |

## Partition Key Considerations
1. **Hash distribution**: `DISTRIBUTED BY (col1)` uses Flink's hash function
2. **Partition count**: Must match Kafka topic partition count
3. **Key skew**: If one key has much more data, distribute by multiple fields
4. **Primary key vs partition key**: They can differ; for upsert mode they should be aligned

## Performance Impact
- Each partition = 18 MB/s bottleneck
- More partitions = more parallelism but higher resource overhead
- 5 partitions feed 1 CFU in Confluent Cloud
- Key skew: add additional fields to `DISTRIBUTED BY` for better distribution

## Partitioned Table (Flink OSS)
```sql
CREATE TABLE user (
    user_id VARCHAR(250),
    name VARCHAR(50)
)
PARTITIONED BY ('user_id')
WITH (
    'connector' = 'filesystem',
    'format' = 'json',
    'path' = '/tmp/users'
);
```

## Confluent Cloud Specifics
- Partition key generates a key schema automatically
- If destination topic has no key, records may be written with whatever partitioning was at query end
- `GROUP BY foo` or `JOIN ON A.foo = B.foo` preserves `foo` partitioning
- `'key.format' = 'raw'` bypasses key schema generation

## Related
- [[primary-key]] state management
- [[watermark]] processing
- [[changelog-mode]] for output
- [[kafka-connector]] topic configuration
