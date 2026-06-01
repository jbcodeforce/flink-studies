# Terraform: Deploy Flink statements to Confluent Cloud

Deploys the cc-flink SQL (customers DDL, insert, dedup_customers CTAS) to an existing environment, Kafka cluster, and Flink compute pool. No resources are created except the three Flink statements.

Alternatively, use the shared Python deploy tools (no Terraform): from `cc-flink/` run `make sync` then `make deploy-customers` (see [`deploy_manifest.json`](../deploy_manifest.json) and [`../../tools/README.md`](../../tools/README.md)).

**Prerequisites:** Environment, Kafka cluster, Flink compute pool, and a service account with an API key scoped to the Flink region must already exist. Set all IDs and credentials in `terraform.tfvars`.

1. Copy `terraform.tfvars.example` to `terraform.tfvars` and fill in values.
2. From this directory: `terraform init`, `terraform plan`, `terraform apply`.
