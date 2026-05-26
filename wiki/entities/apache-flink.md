---
title: Apache Flink
created: 2026-05-23
updated: 2026-05-23
type: entity
tags: [company, open-source]
sources: [raw/articles/flink-sql-ddl-best-practices.md]
confidence: high
---

# Apache Flink

## Overview
Apache Flink is an open-source stream processing framework for distributed, high-performance, always-available, and fault-tolerant real-time data applications. It implements ANSI-standard SQL through its Table API and Flink SQL layer.

## Key Characteristics
- Distributed processing: Scales across clusters
- Fault tolerance: Through checkpointing and exactly-once semantics
- Stateful computations: Maintains state across streaming events via [[flink-sql]]
- Unified batch + streaming: Processes both bounded (batch) and unbounded (stream) data with the same APIs

## Architecture
Flink follows a client-JobManager-TaskManager architecture:
- JobManager coordinates distributed computations
- TaskManager executes streaming operators
- [[apache-flink]] provides fault tolerance

## Deployment Options
- Standalone cluster
- [[confluent-cloud-for-flink]] / [[confluent-platform-for-flink]]
- [[confluent-platform-for-flink]] via Flink Kubernetes Operator
- [[apache-flink]] / Mesos via YARN/Mesos integrations

## APIs
- Flink SQL (ANSI-compatible)
- [[flink-sql]] / [[flink-sql]]
- [[flink-sql]] for complex event processing

## Relevance to Wiki
[[flink-sql]] is the primary interface for defining streaming data pipelines. DDL operations ([[create-table]]) map to [[kafka-connector]] topics in managed deployments. [[changelog-mode]] and [[watermark]] are core SQL concepts. [[medallion-architecture]] patterns are commonly implemented using Flink SQL tables.
