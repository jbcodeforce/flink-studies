# DR Car Rides — Implementation Plan

*Last updated: see git log*

## Overview

Restructure `ccloud/IaC/` from the current monolithic layout into **layered Terraform root modules**, one folder per concern. Each layer is applied independently and passes outputs to the next via `terraform_remote_state` (local backend, same pattern as `IaC-old/import-j9r-env`).

The primary environment (`j9r-env` / `j9r-kafka` / `lsrc-3oxyv2`) already exists and is managed by [`deployment/cc-terraform/`](../../../deployment/cc-terraform/). No changes are made to that stack. Layer 0 only adds what the DR demo needs on the primary side (Flink pool, producer keys, `rides_raw` topic).

---

## Target IaC Directory Layout

```
ccloud/IaC/
├── 00-primary-flink/        # Layer 0 — Flink pool + producer SA/keys on existing j9r-env
│   ├── main.tf              #   providers, data sources for existing primary resources
│   ├── flink.tf             #   confluent_flink_compute_pool.primary, role bindings, API key
│   ├── producer.tf          #   producer SA, Kafka API key, SR API key, rides_raw topic
│   ├── outputs.tf           #   all fields export-env.sh primary needs
│   ├── variables.tf
│   └── terraform.tfvars.example
│
├── 01-dr-site/              # Layer 1 — DR env, Enterprise cluster, SR, Flink pool, SA, keys
│   ├── main.tf              #   providers, remote_state → 00-primary-flink
│   ├── confluent.tf         #   dr env, dr kafka cluster, dr SR data source, dr Flink pool
│   ├── service-accounts.tf  #   dr SA, role bindings, all API keys (Kafka, SR, Flink, producer)
│   ├── outputs.tf           #   all fields export-env.sh dr needs
│   ├── variables.tf
│   └── terraform.tfvars.example
│
├── 02-cluster-link/         # Layer 2 — Destination-initiated Cluster Link + mirror topics
│   ├── main.tf              #   providers, remote_state → 00 + 01
│   ├── cluster-link.tf      #   confluent_cluster_link, confluent_kafka_mirror_topic ×3
│   ├── outputs.tf           #   cluster_link_name, mirror topic names
│   ├── variables.tf
│   └── terraform.tfvars.example
│
├── 03-schema-linking/       # Layer 3 — DR SR IMPORT mode + primary→DR schema exporter
│   ├── main.tf              #   providers, remote_state → 00 + 01
│   ├── schema-linking.tf    #   confluent_schema_registry_cluster_mode (IMPORT), confluent_schema_exporter
│   ├── outputs.tf           #   schema_exporter_name, dr_sr_mode
│   ├── variables.tf
│   └── terraform.tfvars.example
│
└── 04-tableflow/            # Layer 4 — (Optional) S3 + Glue + Tableflow BYOB, both sides
    ├── main.tf              #   providers (confluent + aws), remote_state → 00 + 01
    ├── aws.tf               #   S3 buckets ×2, Glue DBs ×2, IAM role/policy
    ├── tableflow.tf         #   confluent_provider_integration ×2 (primary + dr)
    ├── outputs.tf           #   bucket names, glue DB names, PI IDs, IAM role ARN
    ├── variables.tf
    └── terraform.tfvars.example
```

The current `ccloud/IaC/` flat files (`main.tf`, `dr_site.tf`, `variables.tf`, `outputs.tf`) and `IaC-old/` are **replaced** by the layered structure above. `IaC-old/` can be deleted once the new layers are validated.

---

## Primary Resource IDs (hardcoded in Layer 0 data sources)

| Resource | ID |
|---|---|
| Primary environment | `env-yk3jm6` |
| Primary Kafka cluster | `lkc-7v233w` |
| Primary Schema Registry | `lsrc-3oxyv2` |
| Primary service account | `sa-111z1z` |
| Primary region | `us-west-2` |
| DR region | `us-east-1` |

---

## Layer-by-Layer Tasks

---

### Layer 0 — `ccloud/IaC/00-primary-flink/`

**Status:** [x] DONE — files created in `ccloud/IaC/00-primary-flink/`

#### Task 0.1 — `main.tf`
- `terraform` block: required_version `>= 1.16`, providers `confluentinc/confluent ~> 2.86`
- `provider "confluent"` — credentials from env vars only (no schema_registry_* block; comment warning about unsetting SR env vars)
- `data "confluent_organization" "org"`
- `data "confluent_environment" "primary"` — id = `env-yk3jm6`
- `data "confluent_kafka_cluster" "primary"` — id = `lkc-7v233w`, env ref
- `data "confluent_schema_registry_cluster" "primary"` — id = `lsrc-3oxyv2`, env ref
- `data "confluent_service_account" "primary_sa"` — id = `sa-111z1z`
- `data "confluent_flink_region" "primary"` — cloud = `AWS`, region = `var.primary_region`

#### Task 0.2 — `flink.tf`
- `confluent_flink_compute_pool.primary` — display_name = `${var.prefix}-flink-primary`, cloud = AWS, region = `var.primary_region`, max_cfu = `var.flink_max_cfu`, env = primary
- `confluent_role_binding.flink_developer_primary` — SA = primary_sa, role = `FlinkDeveloper`, crn = primary env resource_name
- `confluent_role_binding.flink_cluster_admin_primary` — SA = primary_sa, role = `CloudClusterAdmin`, crn = primary cluster rbac_crn
- `confluent_api_key.flink_primary` — owner = primary_sa, managed_resource = flink_region.primary in primary env; depends_on role bindings

#### Task 0.3 — `producer.tf`
- `confluent_role_binding.producer_cluster_admin_primary` — SA = primary_sa, role = `CloudClusterAdmin`, crn = primary cluster rbac_crn
- `confluent_role_binding.producer_sr_primary` — SA = primary_sa, role = `ResourceOwner`, crn = `${primary_sr.resource_name}/subject=*`
- `confluent_api_key.producer_primary_kafka` — owner = primary_sa, managed_resource = primary cluster in primary env; depends_on cluster_admin binding
- `confluent_api_key.producer_sr_primary` — owner = primary_sa, managed_resource = primary SR in primary env; depends_on sr binding
- `confluent_kafka_topic.rides_raw` — topic_name = `rides_raw`, partitions = `var.topic_partitions`, retention.ms = `604800000`; credentials = producer_primary_kafka key

#### Task 0.4 — `outputs.tf`
All outputs consumed by `export-env.sh primary`:
```
primary_environment_id, primary_environment_display_name
primary_schema_registry_id, primary_schema_registry_rest_endpoint
primary_kafka_cluster_id, primary_kafka_cluster_display_name
primary_bootstrap_endpoint, primary_rest_endpoint
primary_flink_compute_pool_id
primary_flink_rest_endpoint        (from data.confluent_flink_region.primary)
primary_region                     (= var.primary_region)
flink_api_key_primary (sensitive), flink_api_secret_primary (sensitive)
producer_primary_api_key (sensitive), producer_primary_api_secret (sensitive)
producer_sr_primary_api_key (sensitive), producer_sr_primary_api_secret (sensitive)
```

#### Task 0.5 — `variables.tf`
```hcl
variable "prefix"            { default = "j9r" }
variable "primary_region"    { default = "us-west-2" }
variable "flink_max_cfu"     { default = 10 }
variable "topic_partitions"  { default = 6 }
```

#### Task 0.6 — `terraform.tfvars.example`
Document all variables with example values. Note: credentials via `CONFLUENT_CLOUD_API_KEY` / `CONFLUENT_CLOUD_API_SECRET` env vars.

---

### Layer 1 — `ccloud/IaC/01-dr-site/`

**Status:** [ ] TODO

#### Task 1.1 — `main.tf`
- `terraform` block: same provider versions as Layer 0
- `provider "confluent"` — credentials from env vars
- `data "terraform_remote_state" "primary"` — backend = local, path = `../00-primary-flink/terraform.tfstate`
- `data "confluent_flink_region" "dr"` — cloud = AWS, region = `var.dr_region`
- `data "confluent_organization" "org"`

#### Task 1.2 — `confluent.tf`
- `confluent_environment.dr` — display_name = `${var.prefix}-dr`, stream_governance ESSENTIALS
- `confluent_kafka_cluster.dr` — display_name = `${var.prefix}-dr-kafka`, availability = HIGH, cloud = AWS, region = `var.dr_region`, `enterprise {}`, env = dr
- `data "confluent_schema_registry_cluster" "dr"` — env = dr; depends_on = kafka cluster (SR auto-provisioned after cluster)
- `confluent_flink_compute_pool.dr` — display_name = `${var.prefix}-flink-dr`, cloud = AWS, region = `var.dr_region`, max_cfu = `var.flink_max_cfu`, env = dr

#### Task 1.3 — `service-accounts.tf`
- `confluent_service_account.dr_manager` — display_name = `${var.prefix}-dr-manager`
- Role bindings on dr env/cluster/SR:
  - `EnvironmentAdmin` on dr env
  - `FlinkDeveloper` on dr env
  - `CloudClusterAdmin` on dr cluster (for Flink)
  - `CloudClusterAdmin` on dr cluster (for producer)
  - `ResourceOwner` on dr SR subjects (for producer)
- API keys (all owner = dr_manager SA):
  - `confluent_api_key.flink_dr` — managed_resource = flink_region.dr in dr env
  - `confluent_api_key.producer_dr_kafka` — managed_resource = dr cluster in dr env
  - `confluent_api_key.producer_sr_dr` — managed_resource = dr SR in dr env

#### Task 1.4 — `outputs.tf`
All outputs consumed by `export-env.sh dr`:
```
dr_environment_id, dr_environment_display_name
dr_schema_registry_id, dr_schema_registry_rest_endpoint
dr_kafka_cluster_id, dr_kafka_cluster_display_name
dr_bootstrap_endpoint, dr_rest_endpoint
dr_flink_compute_pool_id
dr_flink_rest_endpoint              (from data.confluent_flink_region.dr)
dr_region                           (= var.dr_region)
flink_api_key_dr (sensitive), flink_api_secret_dr (sensitive)
producer_dr_api_key (sensitive), producer_dr_api_secret (sensitive)
producer_sr_dr_api_key (sensitive), producer_sr_dr_api_secret (sensitive)
dr_manager_sa_id                    (needed by layers 02 and 03)
```

#### Task 1.5 — `variables.tf`
```hcl
variable "prefix"        { default = "j9r" }
variable "dr_region"     { default = "us-east-1" }
variable "flink_max_cfu" { default = 10 }
```

#### Task 1.6 — `terraform.tfvars.example`

---

### Layer 2 — `ccloud/IaC/02-cluster-link/`

**Status:** [ ] TODO

#### Task 2.1 — `main.tf`
- Providers: confluent ~> 2.86
- `data "terraform_remote_state" "primary"` — path `../00-primary-flink/terraform.tfstate`
- `data "terraform_remote_state" "dr"` — path `../01-dr-site/terraform.tfstate`
- Local values wiring IDs from remote states (primary cluster, dr cluster, API keys for each side)

#### Task 2.2 — `cluster-link.tf`
- `confluent_kafka_topic.rides_clean` and `confluent_kafka_topic.driver_stats` — create on primary (rides_raw already created in Layer 0); partitions = `var.topic_partitions`, retention.ms = `604800000`; credentials from remote_state primary producer key
- `confluent_cluster_link.primary_to_dr` — link_mode = `DESTINATION`, connection_mode = `OUTBOUND`; source = primary cluster + API key from remote_state; destination = dr cluster + API key from remote_state
- `confluent_kafka_mirror_topic.dr` for_each of `{rides_raw, rides_clean, driver_stats}` — cluster_link = primary_to_dr, kafka_cluster = dr

#### Task 2.3 — `outputs.tf`
```
cluster_link_name   (= var.cluster_link_name, consumed by export-env.sh)
mirror_topics       (list)
```

#### Task 2.4 — `variables.tf`
```hcl
variable "cluster_link_name"  { default = "dr-rides-primary-to-dr" }
variable "topic_partitions"   { default = 6 }
```

#### Task 2.5 — `terraform.tfvars.example`

---

### Layer 3 — `ccloud/IaC/03-schema-linking/`

**Status:** [ ] TODO

#### Task 3.1 — `main.tf`
- Providers: confluent ~> 2.86
- `data "terraform_remote_state" "primary"` — path `../00-primary-flink/terraform.tfstate`
- `data "terraform_remote_state" "dr"` — path `../01-dr-site/terraform.tfstate`
- Local values wiring SR IDs and API keys from remote states

#### Task 3.2 — `schema-linking.tf`
- `confluent_schema_registry_cluster_mode.dr_import` — mode = `IMPORT`, force = true; SR = dr SR; credentials = dr SR API key from remote_state; depends_on dr env admin binding
- `confluent_schema_exporter.primary_to_dr` — name = `${var.prefix}-schemas-to-dr`; subjects = `[":*:"]`; source SR = primary SR + primary SR API key; destination SR = dr SR + dr SR API key; depends_on dr_import mode

#### Task 3.3 — `outputs.tf`
```
schema_exporter_name    (consumed by export-env.sh)
dr_schema_registry_mode (= "IMPORT" while exporter is running)
```

#### Task 3.4 — `variables.tf`
```hcl
variable "prefix" { default = "j9r" }
```

#### Task 3.5 — `terraform.tfvars.example`

---

### Layer 4 — `ccloud/IaC/04-tableflow/`

**Status:** [ ] TODO (optional, gate with `enable_tableflow`)

#### Task 4.1 — `main.tf`
- Providers: confluent ~> 2.86, aws ~> 5.0 (two provider aliases: `aws.primary` and `aws.dr`)
- `data "terraform_remote_state" "primary"` + `data "terraform_remote_state" "dr"`
- `data "aws_caller_identity" "current"`
- Local values: bucket names, glue DB names, IAM role ARN

#### Task 4.2 — `aws.tf`
- `aws_s3_bucket.iceberg_primary` + versioning + AES-256 SSE (provider = aws.primary)
- `aws_s3_bucket.iceberg_dr` + versioning + AES-256 SSE (provider = aws.dr)
- `aws_glue_catalog_database.primary` (provider = aws.primary)
- `aws_glue_catalog_database.dr` (provider = aws.dr)
- `aws_iam_role.tableflow` + trust policy (Confluent account `197857026523`, external_id from var)
- `aws_iam_role_policy.tableflow_combined` — S3 + Glue permissions on both buckets/DBs

#### Task 4.3 — `tableflow.tf`
- `confluent_provider_integration.tableflow_primary` — env = primary, IAM role ARN
- `confluent_provider_integration.tableflow_dr` — env = dr, IAM role ARN

#### Task 4.4 — `outputs.tf`
```
primary_s3_bucket_name, dr_s3_bucket_name
glue_database_primary, glue_database_dr
tableflow_provider_integration_id_primary, tableflow_provider_integration_id_dr
tableflow_role_arn
```

#### Task 4.5 — `variables.tf`
```hcl
variable "prefix"               { default = "j9r" }
variable "aws_region_primary"   { default = "us-west-2" }
variable "aws_dr_region"        { default = "us-east-1" }
variable "confluent_external_id" { sensitive = true }
variable "enable_tableflow"      { default = true }
```

#### Task 4.6 — `terraform.tfvars.example`

---

### Additional Tasks — Scripts, Flink SQL, Tooling

#### Task 5 — Consolidate `iac-outputs.json` for `export-env.sh`

`export-env.sh` reads a single merged `iac-outputs.json`. Update `scripts/README.md` (or add a `Makefile` target `make outputs`) that merges outputs from all applied layers:

```bash
# generate-outputs.sh  (new helper)
terraform -chdir=../IaC/00-primary-flink output -json > /tmp/out0.json
terraform -chdir=../IaC/01-dr-site       output -json > /tmp/out1.json
terraform -chdir=../IaC/02-cluster-link  output -json > /tmp/out2.json
terraform -chdir=../IaC/03-schema-linking output -json > /tmp/out3.json
jq -s 'reduce .[] as $x ({}; . * $x)' /tmp/out0.json /tmp/out1.json /tmp/out2.json /tmp/out3.json \
  > iac-outputs.json
```

Add `generate-outputs.sh` to `ccloud/scripts/`.

#### Task 6 — Flink SQL: DR-aware DDL for `rides_raw`

`seed/ddl.rides_raw.sql` creates the primary source topic. On the DR site the topic already exists as a mirror — deploying the same DDL would try to re-create it.

- Add `ccloud/flink-sql/seed/ddl.rides_raw_dr.sql` — `CREATE TABLE IF NOT EXISTS rides_raw (...)` with connector properties pointing to the existing mirror (no `kafka.cleanup.policy`, same schema).
- Update `deploy_manifest.json` to use the `_dr` variant when `SITE=dr` (or add a `dr_manifest.json` alongside the main one and have the Makefile select it via `MANIFEST ?= deploy_manifest.json`).

#### Task 7 — Flink SQL: confirm `earliest-offset` on DR DML

Review [`dims/dml.rides_clean.sql`](./flink-sql/dims/dml.rides_clean.sql) and [`facts/dml.driver_stats.sql`](./flink-sql/facts/dml.driver_stats.sql). If `scan.startup.mode` is not set, add a Makefile variable or a DR-specific DML override so the DR deployment starts from `earliest-offset` to rebuild state from the mirror.

#### Task 8 — `assess_loss.py`: align CLI flags

`failover-soft.sh` calls:
```bash
uv run assess_loss.py --producer-log ... --pre-failover-max-seq <N> --post-mirror-max-seq <M>
```
`ccloud/README.md` shows `--sample-topic`. Audit `python/assess_loss.py` and reconcile the actual flag names so the failover script runs without error.

#### Task 9 — `failover-soft.sh`: pass `--environment` + `--compute-pool` to CLI calls

Replace bare `confluent flink statement stop "$name"` with:
```bash
confluent flink statement stop "$name" \
  --environment "$CONFLUENT_ENVIRONMENT_ID" \
  --compute-pool "$FLINK_COMPUTE_POOL_ID"
```
Both variables are already exported by `export-env.sh`.

#### Task 10 — Remove `ccloud/IaC/` flat files and `IaC-old/`

Once all four layers are applied and validated end-to-end:
- Delete `ccloud/IaC/main.tf`, `dr_site.tf`, `variables.tf`, `outputs.tf` (current flat files)
- Delete `ccloud/IaC-old/` directory tree
- Update `ccloud/README.md` step-by-step to reference the new layer paths

---

## Apply Order

```
cd ccloud/IaC/00-primary-flink  && terraform init && terraform apply
cd ../01-dr-site                && terraform init && terraform apply
cd ../02-cluster-link           && terraform init && terraform apply
cd ../03-schema-linking         && terraform init && terraform apply
cd ../04-tableflow              && terraform init && terraform apply   # optional
cd ../../scripts && ./generate-outputs.sh
source export-env.sh primary
cd ../flink-sql && make deploy SITE=primary
cd ../../python && uv run produce_rides.py --interval 0.5
```

## Teardown Order (reverse)

```
cd ccloud/IaC/04-tableflow      && terraform destroy   # if applied
cd ../03-schema-linking         && terraform destroy
cd ../02-cluster-link           && terraform destroy
cd ../01-dr-site                && terraform destroy
cd ../00-primary-flink          && terraform destroy   # removes pool + topics, not j9r-env itself
```
