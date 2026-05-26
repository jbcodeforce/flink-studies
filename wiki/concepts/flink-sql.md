---
title: Flink SQL
created: 2026-05-23
updated: 2026-05-23
type: concept
tags: [sql, api]
sources: [raw/articles/flink-sql-ddl-best-practices.md, raw/articles/flink-basics.md]
confidence: high
---

# Flink SQL

## Overview
Flink SQL provides an ANSI-standard SQL interface for defining streaming data pipelines within Apache Flink. It supports both [[Data Definition Language|DDL]] and [[Data Manipulation Language|DML]] operations.

## SQL Layers
Flink SQL sits on top of the [[flink-sql]], providing:
- Table source definitions (CREATE TABLE for inputs)
- Table sink definitions (CREATE TABLE for outputs)
- Query expressions (SELECT, INSERT, JOIN, WINDOW)

## Key SQL Constructs

### DDL Operations
- [[create-table]] / [[create-table]] / [[create-table]] tables and views
- [[flink-sql]] and [[flink-sql]] management
- [[watermark]] strategy definition

### Query Semantics
- [[changelog-mode]]: controls how changes propagate (append, upsert, retract)
- [[watermark]]: tumble, slide, session, custom windows
- [[flink-sql]]: temporal, regular, interval joins

## Management by Environment

| Deployment | Metadata Model | Partitioning |
|------------|---------------|--------------|
| Standalone | Catalogs/databases/tables | User-defined |
| [[confluent-cloud-for-flink]] | Environment/clusters/topics | CFU-based |
| [[confluent-platform-for-flink]] | Catalogs/clusters/topics | User-defined |

## Key Principles
- [[primary-key]] declaration implicitly partitions the table
- The query plan changes depending on the destination [[changelog-mode]]
- Use `DESCRIBE EXTENDED table_name` to diagnose table configuration
- Use `EXPLAIN` to inspect query semantics before execution

## Related Concepts
- [[create-table]] syntax and options
- [[materialized-table]] for data freshness management
- [[view]] for read-only query encapsulation
- [[schema-registry]] through Avro Schema Registry integration
