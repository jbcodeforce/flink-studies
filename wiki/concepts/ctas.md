---
title: CTAS (Create Table As Select)
created: 2026-05-23
updated: 2026-05-23
type: concept
tags: [sql, ddl]
sources: [raw/articles/flink-sql-ddl-best-practices.md]
confidence: high
---

# CTAS (Create Table As Select)

## Overview
[CTAS](https://docs.confluent.io/cloud/current/flink/reference/statements/create-table.html#create-table-as-select-ctas) is a Flink SQL statement that creates a table and inserts data in a single statement. It derives physical types, names, [[changelog-mode]], and [[primary-key]] from the SELECT query.

## Syntax
```sql
CREATE TABLE new_table
DISTRIBUTED BY (key_col) INTO N BUCKETS
AS SELECT col1, col2 AS renamed_col FROM source_table;
```

## Derivation Rules
- **Column types/names**: Derived from aliased SELECT columns
- **Changelog mode**: Derived from involved tables and operations
- **Primary key**: Derived from PRIMARY KEY or DISTINCT clauses
- **Physical layout**: Derived from DISTRIBUTED BY clause

## Example
```sql
CREATE TABLE shoe_customer_keyed (
    PRIMARY KEY (id) NOT ENFORCED
) DISTRIBUTED BY (id) INTO 1 BUCKETS
AS SELECT id, first_name, last_name, email FROM shoe_customers;
```

## Use Cases
- Rapid table creation from existing queries
- Materializing intermediate results
- Creating dimension tables from transaction streams
- Quick deduplication via CTAS with primary keys

## Limitations
- Changelog mode is derived, not directly specified
- Physical partitioning must match primary keys for upsert
- Limited control over format options (use WITH clause instead)

## Related
- [[create-table]] for full DDL control
- [[materialized-table]] for managed evolution
- [[view]] for read-only derivation without physical storage
- [[kafka-connector]] partitioning considerations
