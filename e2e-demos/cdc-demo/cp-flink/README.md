# CDC Debezium demo – Confluent Platform

## Goal

Run PostgreSQL CDC with Debezium on Kubernetes, stream to Kafka, and consume with Flink SQL. Covers loan_applications and transactions tables, `message.key.columns`, and Confluent Platform / K8s.

## Status

Ready. Requires Kubernetes with Confluent Platform (Kafka, Connect). Datasets and root Makefile at demo root.

## Implementation approach

- **No Terraform:** K8s manifests in `infrastructure/` (PostgreSQL/CloudNativePG, Kafka Connect, Debezium connector, Flink jobmanager/taskmanager). Root Makefile drives deployment.
- **Application logic:** Flink DDL in `src/flink-sql/`, Python data loaders in `src/` (use datasets at root). Run from demo root: `make demo_setup`, `make deploy_connect`, `make demo_run`, `make deploy_flink`, etc.

## How to run

From the **demo root** (parent of this folder):

1. Prerequisites: K8s cluster, Confluent Platform (see [../../deployment/k8s/](../../deployment/k8s/)).
2. `make demo_setup` – PostgreSQL, tables, sample data.
3. `make deploy_connect` – Kafka Connect, Debezium connector.
4. `make demo_run` – Optional: load more data.
5. `make deploy_flink` – Flink cluster; then use DDL in `cp-flink/src/flink-sql/` in Flink SQL client (`make flink_sql_client`).

See root [Readme.md](../Readme.md) for full flow and architecture.
