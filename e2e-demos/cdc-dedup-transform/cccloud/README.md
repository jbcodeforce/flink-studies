# Qlik CDC dedup & transform – Confluent Cloud

## Goal

Run the Qlik CDC pipeline on Confluent Cloud: raw CDC envelope → filter/dedup (src_customers) → business validation and dimension/fact tables → S3/Iceberg sink. Demonstrates REFRESH/INSERT/UPDATE/DELETE handling, DLQ, and delete propagation.

## Status

Ready. Requires Confluent Cloud (Kafka, Schema Registry, Flink compute pool). Optional: Terraform in `IaC/` for provisioning.

## Implementation approach

- **IaC:** Terraform in `IaC/` for Confluent Cloud resources (see `IaC/README.md` or root README). Can also use Flink SQL Workspace and Confluent CLI without Terraform.
- **Application logic:** Flink SQL in `customers/` (src_customers, dim_groups, fact_customers with sql-scripts and Makefiles). Test raw table and insert data in `raw_topic_for_tests/`. Deploy via Makefiles or copy-paste in Flink Workspace.

## How to run

### Prerequisites

Confluent Cloud environment, Flink compute pool. Confluent CLI optional for Makefile-based deployment.

### Steps

1. **Create raw CDC table and test data:** From `cccloud/raw_topic_for_tests/`, run DDL (`ddl.cdc_raw_table.sql`) in Flink Workspace or `make create_raw_table`, then insert test data (`insert_raw_test_data.sql` or `make insert_raw_data`).
2. **Deploy pipeline:** Under `cccloud/customers/src_customers`, run DDL and DML (Makefile or Workspace). Then deploy `customers/dim_groups` and `customers/fact_customers` in order.
3. **Validate:** Run validation SQL from the `customers` subfolders or root README.

Full pipeline logic and SQL examples: see root [README.md](../README.md).
