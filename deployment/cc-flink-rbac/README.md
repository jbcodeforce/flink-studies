# Flink RBAC study — FlinkDeveloper service account

Terraform module for a **GCP** Confluent Cloud sandbox: environment (optional), **Standard** Kafka cluster, Flink compute pool, and a **FlinkDeveloper** service account with least-privilege Kafka bindings (`DeveloperRead` / `DeveloperWrite` on topics and Flink transactional IDs). Includes a shell example that deploys a Flink SQL statement via the REST API.

## What it creates

| Resource | Default | Purpose |
| -------- | ------- | ------- |
| `confluent_environment.env` | `create_environment = false` | Confluent Cloud environment |
| `confluent_kafka_cluster.kafka` | `create_kafka_cluster = true` | **Standard** Kafka cluster (required for topic-level RBAC) |
| `confluent_flink_compute_pool.pool` | `create_flink_compute_pool = true` | Flink compute pool |
| `confluent_service_account.flink_developer` | always | Principal that runs Flink statements |
| `confluent_role_binding.flink_developer` | always | `FlinkDeveloper` on the environment |
| `confluent_role_binding.flink_developer_topic_*` | Standard Kafka | `DeveloperRead` / `DeveloperWrite` / `DeveloperManage` on `topic=*` |
| `confluent_role_binding.flink_developer_txn_*` | Standard Kafka | `DeveloperRead` / `DeveloperWrite` on `transactional-id=_confluent-flink_*` |
| `confluent_role_binding.flink_developer_sr_*` | Standard Kafka + SR | `DeveloperRead` / `DeveloperWrite` on `subject=*` (Avro CREATE TABLE) |
| `confluent_api_key.flink_developer` | always | Flink-scoped API key (statements + RBAC negative tests) |

No `CloudClusterAdmin`, `EnvironmentAdmin`, or `OrganizationAdmin` roles are granted to the FlinkDeveloper service account.

For `CREATE TABLE` with `avro-registry`, the module grants `DeveloperManage` on Kafka topics plus Schema Registry `DeveloperRead` / `DeveloperWrite` on subjects (defaults: wildcard `*`).

Terraform apply still requires an org-admin **Cloud API key** in the environment (`CONFLUENT_CLOUD_API_KEY` / `CONFLUENT_CLOUD_API_SECRET`) to provision resources. That is operator credentials, not a role on the Flink SA.

Tighten `kafka_topic_pattern` and `schema_registry_subject_pattern` in `terraform.tfvars` for production least privilege.

## Prerequisites

- Confluent Cloud API credentials with **OrganizationAdmin**, via environment variables:
  ```bash
  export CONFLUENT_CLOUD_API_KEY="<org-admin-key>"
  export CONFLUENT_CLOUD_API_SECRET="<org-admin-secret>"
  ```
- Terraform >= 1.3

If `terraform plan` fails on Schema Registry provider attributes, you likely have partial `SCHEMA_REGISTRY_*` variables in your shell. This module sets all four SR provider fields to empty by default to avoid that.

## Apply

```bash
export CONFLUENT_CLOUD_API_KEY="<org-admin-key>"
export CONFLUENT_CLOUD_API_SECRET="<org-admin-secret>"

cd deployment/cc-flink-rbac
cp terraform.tfvars.example terraform.tfvars

terraform init
terraform plan
terraform apply
```

**Existing environment** (Standard Kafka + pool only):

```hcl
create_environment        = false
environment_id            = "env-xxxxx"
environment_display_name  = "j9r-env"   # sql.current-catalog; use the UI name, not {prefix}-env
create_kafka_cluster      = true
create_flink_compute_pool = true
kafka_cluster_tier        = "standard"
```

`prefix` only names **new** resources created by this module (e.g. `j9rgcp-kafka`). It does not rename an existing environment. Set `environment_display_name` to the catalog name shown in Confluent Cloud (often different from `prefix`).

If you previously applied a **Basic** cluster, switching to Standard forces cluster replacement. Remove the old Basic cluster from state or run `terraform apply` and accept the replace.

## Deploy a statement via REST API

After `terraform apply`:

```bash
chmod +x examples/deploy_statement.sh
./examples/deploy_statement.sh
```

Default statement: `CREATE TABLE gcp_demo` from `examples/ddl.gcp_demo.sql`.

Custom SQL file or inline SQL:

```bash
SQL_FILE=examples/ddl.gcp_demo.sql STATEMENT_NAME=rbac-gcp-demo ./examples/deploy_statement.sh
STATEMENT_NAME=select-1 SQL='SELECT 1;' ./examples/deploy_statement.sh
```

## RBAC negative test (compute pool)

`FlinkDeveloper` can deploy statements but cannot create compute pools (`FlinkAdmin` required). After `terraform apply`:

```bash
chmod +x examples/create_compute_pool_denied.sh
./examples/create_compute_pool_denied.sh
```

Uses the same **Flink-scoped API key** as `deploy_statement.sh` against `POST https://api.confluent.cloud/fcpm/v2/compute-pools`. Confluent documents that endpoint with a Cloud API key; with the FlinkDeveloper's Flink key you should still get a failure (typically **401** or **403**). Exit code **0** means denial worked. Exit code **1** means a pool was created unexpectedly.

## Related

- AWS base infrastructure: [deployment/cc-terraform](../cc-terraform/)
- Python REST client: `code/flink-sql/tools/cc_deploy/cc_flink_rest_client.py`
