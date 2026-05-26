---
title: Primary Key
created: 2026-05-23
updated: 2026-05-23
type: concept
tags: [sql, metadata, state]
sources: [raw/articles/flink-sql-ddl-best-practices.md]
confidence: high
---

# Primary Key

## Overview
In Flink SQL, a [[primary-key]] enables stateful operations like deduplication and updates. Declared with `NOT ENFORDED` for performance, it doesn't add runtime checks but informs the planner.

## Primary Key vs Partition Key
- **Primary key**: Determines [[changelog-mode]], state keys, and dedup behavior
- **Partition key**: Determines which Kafka partition a message lands on (physical layout)

## NOT ENFORCED Constraint
```sql
PRIMARY KEY(user_id) NOT ENFORCED
```
- `NOT ENFORCED` skips runtime PK validation (performance optimization)
- The planner still uses the key for state management
- Required for [[changelog-mode]] changelog mode

## State Management Impact
The primary key:
1. Enables incremental state (only stores latest per key)
2. Allows [[changelog-mode]] semantics for deduplication
3. Implicitly partitions the table for join optimization
4. Determines [[kafka-partitioning]] mapping for physical storage

## Bucket Key Rules
| Changelog Mode | Bucket Key Requirement |
|---------------|----------------------|
| upsert | Must equal primary key |
| append/retract | Can be subset of primary key |

## Common Patterns

### Simple Primary Key
```sql
CREATE TABLE orders (
    order_id STRING PRIMARY KEY NOT ENFORCED,
    customer_id INT,
    amount DOUBLE
);
```

### Composite Primary Key
```sql
CREATE TABLE events (
    key1 STRING,
    key2 STRING,
    data STRING,
    PRIMARY KEY(key1, key2) NOT ENFORCED
) DISTRIBUTED BY (key1, key2);
```

## Related
- [[changelog-mode]] for upsert semantics
- [[kafka-connector]] partitioning and bucket mapping
- [[watermark]] for event-time semantics
- [[materialized-table]] for managed state evolution
