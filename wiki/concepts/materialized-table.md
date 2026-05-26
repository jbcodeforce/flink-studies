---
title: Materialized Table
created: 2026-05-23
updated: 2026-05-23
type: concept
tags: [sql, state]
sources: [raw/articles/flink-sql-ddl-best-practices.md]
confidence: high
---

# Materialized Table

## Overview
A [[materialized-table]] is a Flink SQL abstraction for managed streaming tables that track data freshness and provide automatic state evolution. Introduced to support safe evolution of streaming queries without manual stop/delete/recreate cycles.

## Key Features
- **Data Freshness**: Declared maximum lag with `FRESHNESS = INTERVAL '<n>' <unit>`
- **Refresh Modes**: FULL (batch snapshots) or CONTINUOUS (streaming updates)
- **State Management**: Automated offset and state handling
- **Schema Evolution**: Schema inferred from query; evolves with the query
- **Safe Updates**: CREATE OR ALTER instead of drop/recreate

## Syntax
```sql
CREATE MATERIALIZED TABLE table_name
    PRIMARY KEY (col) NOT ENFORCED
    FRESHNESS = INTERVAL '5' MINUTE
    REFRESH_MODE = CONTINUOUS
AS SELECT col1, col2 FROM source_table;
```

## Refresh Mode Comparison

| Mode | Behavior | Use Case |
|------|----------|----------|
| **FULL** | Batch snapshot recompute from bounded/source snapshots (e.g., Iceberg/Delta). Atomic swap. Low-velocity data, nightly refresh. | Nightly reconciliation, batch-heavy pipelines |
| **CONTINUOUS** | Streaming updates from unbounded sources. 24/7 processing. High-velocity data. | Real-time dashboards, live monitoring |

## Benefits Over Regular Tables
- No manual offset management
- Built-in freshness guarantees
- Safe query evolution (CREATE OR ALTER)
- Atomic content swaps (FULL mode)
- Reduced state management burden

## Use Cases
- Dashboard refresh (controlled by FRESHNESS)
- Dimension table maintenance
- Materialized views over CDC sources
- Reconciliation tables over time series

## Related
- [[view]] for read-only vs writable
- [[watermark]] for event-time semantics
- [[changelog-mode]] for change propagation
- [[primary-key]] implications
