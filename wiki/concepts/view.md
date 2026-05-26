---
title: View (SQL)
created: 2026-05-23
updated: 2026-05-23
type: concept
tags: [sql, ddl]
sources: [raw/articles/flink-sql-ddl-best-practices.md]
confidence: high
---

# View (SQL)

## Overview
A [[view]] in Flink SQL is a read-only named query. It acts as a virtual table that refers to the result of a SELECT statement, encapsulating complex logic for reuse.

## Key Characteristics
- **Read-only**: Cannot INSERT INTO a view (no data persistence)
- **Physical**: Stored as metadata; shares namespace with [[CREATE TABLE|tables]]
- **Logical**: No data storage; evaluates the underlying query on access
- **Reusability**: Complex queries can be referenced as simple table names

## Syntax
```sql
CREATE VIEW IF NOT EXISTS vw_name AS SELECT col1, col2 FROM source_table;
```

## Use Cases
- Encapsulating complex JOIN/WINDOW logic
- Defining reusable transformations
- Implementing virtual tables over [[materialized-table]]
- Query templating for dashboards

## View vs Materialized Table

| Aspect | View | Materialized Table |
|--------|------|-------------------|
| Storage | None (logical) | Physical (Kafka topic) |
| Write access | No | Yes (via upsert) |
| Freshness | Current (evaluates query) | Configured (FRESHNESS) |
| State | None | Stored (incremental state) |
| Primary key | No | Yes |

## Notes
- Views and tables share the same namespace in Flink
- Can use [[materialized-table]] when physical refresh and state are needed
- For large datasets, consider materializing as a table for better performance

## Related
- [[create-table]] for physical table creation
- [[materialized-table]] for managed physical views
- [[changelog-mode]] for update semantics
- [[view]] and table namespace
