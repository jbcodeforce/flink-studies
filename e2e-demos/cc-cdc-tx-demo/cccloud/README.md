# CC CDC Transaction Demo – Confluent Cloud

## Goal

Run the full Confluent Cloud CDC transaction demo: AWS RDS PostgreSQL → Debezium CDC → Kafka → Flink (dedup, enrichment, sliding-window aggregates) → TableFlow → Iceberg/S3, with AWS Glue and Athena. Optional ML scoring via ECS/Fargate.

## Status

Ready. Requires AWS account (RDS, S3, Glue, Athena, ECS optional) and Confluent Cloud (Kafka, connectors, Flink compute pool). See root [README.md](../README.md) for architecture and goals.

## Implementation approach

- **IaC:** Terraform in `IaC/` provisions RDS (or uses existing VPC), Confluent Cloud environment, Kafka cluster, CDC connector, Flink compute pool, S3 bucket, TableFlow, Glue catalog integration, and optional ECS task for ML scoring.
- **Application logic:** Flink SQL in `cc-flink-sql/` (Kimball-style: sources, dimensions, facts). Deploy statements via Makefiles under each component or via `cc-flink-sql/terraform/` (Terraform for Flink statements).
- **Data generators / ML:** `data-generators/` and `tx_scoring/` live at demo root; run after infrastructure and Flink pipelines are up.

## How to run

### Prerequisites

- AWS CLI, Terraform, Confluent Cloud account. Set variables (see `IaC/terraform.tfvars.example` and root README).

### Steps

1. **Provision infrastructure:** From `cccloud/IaC/`, run `terraform init` and `terraform apply`. This creates RDS, Confluent Cloud resources, connectors, compute pool, S3, Glue, etc.
2. **Deploy Flink statements:** Either use the Makefiles under `cccloud/cc-flink-sql/` (sources → dimensions → facts) or the Terraform in `cccloud/cc-flink-sql/terraform/` (see [cc-flink-sql/terraform/README.md](cc-flink-sql/terraform/README.md)).
3. **Run data generators** (from root `data-generators/`) and optionally deploy **ML scoring** (root `tx_scoring/`).

Full ordering, TableFlow, and monitoring: see root [README.md](../README.md).
