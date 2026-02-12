# Terraform: Deploy Flink statements to Confluent Cloud

Deploys the cc-flink SQL (customers DDL, insert, dedup_customers CTAS) to an existing environment, Kafka cluster, and Flink compute pool. No resources are created except the three Flink statements.

**Prerequisites:** Environment, Kafka cluster, Flink compute pool, and a service account with an API key scoped to the Flink region must already exist. Set all IDs and credentials in `terraform.tfvars`.

1. Copy `terraform.tfvars.example` to `terraform.tfvars` and fill in values.
2. From this directory: `terraform init`, `terraform plan`, `terraform apply`.
