# Confluent Cloud — DR Car Rides

## Goal

Provision **DR** Confluent Cloud environment/cluster (primary reuses existing `j9r-env` / `j9r-kafka`), run Flink SQL pipelines on car-ride events, mirror topics with Cluster Linking, **replicate schemas with Schema Linking** (preserving Schema IDs in `IMPORT` mode), optionally materialize aggregates with Tableflow/Glue, and practice soft + promote failover with sequence-based loss assessment.

![](../docs/cc-raw-to-sink.drawio.png)

## Status

Requires CC org + AWS credentials. **Attention**, dual Standard clusters, dual Stream Governance, and Tableflow incur cost.

## Implementation approach

| Phase | Location | What |
|-------|----------|------|
| 0 — Primary Catalog | [`IaC/import-j9r-env/`](./IaC/import-j9r-env/) | Import existing `j9r-env` / `j9r-kafka` + outputs for remote state |
| 1 — DR Infrastructure | [`IaC/`](./IaC/) | Terraform (incremental): provision DR env/Kafka/SR/SAs/Flink pools, Cluster Link & Schema Link |
| 2 — Flink Pipelines | [`flink-sql/`](./flink-sql/) | Flink DDL/DML deployed via `make` and `deploy_manifest.json` |
| 3 — Continuous Producer & Consumer | [`../python/`](../python/) | Platform-agnostic producer (`produce_rides.py`) and loss assessment (`assess_loss.py`) |
| 4 — Operations & Failover | [`scripts/`](./scripts/) | Soft/promote failover, failback, environment export (`export-env.sh`) |
| 5 — Data Lakehouse | [`IaC/aws.tf`](./IaC/aws.tf) | Confluent Tableflow + AWS Glue / S3 for Iceberg tables |


### Prerequisites

- Terraform `>= 1.3`, Confluent Cloud API key with org access
- Confluent Cloud [terraform provider](https://registry.terraform.io/providers/confluentinc/confluent/latest) - version 2.81.0+
- Existing `j9r-env` primary (imported under `IaC/import-j9r-env/`; apply that stack first so outputs exist)
- AWS credentials (S3 + Glue + IAM for Tableflow BYOB)
- Python 3.12+ with `uv` (`confluent-kafka[schema-registry,json]`, `pydantic`)
- Optional: Confluent CLI for promote / statement stop / exporter pause

---

## Step-by-Step Walkthrough

### 1. Refresh import outputs (once)

* Ensure terraform variables in `ccloud/IaC/import-j9r-env/` are configured:
  Defaults: `primary_region = us-west-2` (j9r-kafka), `dr_region = us-east-1`.

* Run:
  ```bash
  cd ccloud/IaC/import-j9r-env
  export CONFLUENT_CLOUD_API_KEY=...
  export CONFLUENT_CLOUD_API_SECRET=...
  terraform init && terraform apply
  cd ..
  ```

### 2. Set DR Environment and Cluster

```bash
cd ccloud/IaC
cp terraform.tfvars.example terraform.tfvars
# ensure: enable_cluster_link=false, enable_schema_linking=false, enable_tableflow=false
terraform init && terraform apply
terraform output -json > ../scripts/iac-outputs.json
```

![](../docs/DR-env-clust-cp.png)

### 3. Enable Cluster Linking and Schema Linking

* Update `ccloud/IaC/terraform.tfvars`:
  ```hcl
  enable_cluster_link   = true
  enable_schema_linking = true
  ```

* Apply Terraform to establish the Cluster Link, create mirror topics, and start Schema Exporter (`primary_to_dr` with DR SR in `IMPORT` mode):
  ```bash
  cd ../ccloud/IaC
  terraform apply
  terraform output -json > ../scripts/iac-outputs.json
  ```


### 4. Deploy Primary Flink Statements

```bash
cd ../flink-sql
# Sync tooling once:
make sync

# Deploy statements to primary compute pool:
make deploy SITE=primary
```

You will see statements created on the primary cluster:
- `flink-sql-seed-ddl-rides-raw`
- `flink-sql-dims-ddl-rides-clean`
- `flink-sql-facts-ddl-driver-stats`
- `flink-sql-dims-pipeline-rides-clean`
- `flink-sql-facts-pipeline-driver-stats`

### 5. Produce Records to `rides_raw`

* Set environment variables to reach primary cluster:
  ```bash
  cd ../scripts
  source export-env.sh primary
  ```

* Run continuous producer:
  ```bash
  cd ../../python
  uv sync
  uv run produce_rides.py --interval 0.5
  ```

Producer does **not** auto-register schemas; it uses `use.latest.version` against `rides_raw-key` / `rides_raw-value` created by Flink DDL.


---

## Failover Runbook & Loss Assessment Walkthrough

### 1. Graceful (Soft) Failover

Execute the soft failover script in a separate Terminal:

```bash
cd ccloud/scripts
./failover-soft.sh
```

This will:
1. Stop primary Flink DML statements (`flink-sql-dims-pipeline-rides-clean`, `flink-sql-facts-pipeline-driver-stats`).
2. Instruct Schema Registry mode transition (switch DR SR from `IMPORT` to `READWRITE`).
3. Deploy Flink statements on the DR compute pool (`make deploy SITE=dr`).


Retarget the producer to the DR site:
```bash
source ./export-env.sh dr
cd ../../python
uv run produce_rides.py --interval 0.5
```

### 3. Measure RPO and Sequence Loss

Sample the mirrored topic directly or evaluate against the producer log:

```bash
cd ../../python
uv run assess_loss.py --producer-log /tmp/dr-car-rides-seq.log --sample-topic rides_raw
```

### 4. Ungraceful (Promote) Failover (Optional)

If the primary cluster is unavailable and mirrors must be converted to independent writable topics:

```bash
cd ../ccloud/scripts
./failover-promote.sh
```

### 5. Failback to Primary

Follow the failback procedure:

```bash
cd ../ccloud/scripts
./failback.sh
```

---

## Catalog Cutover & Tableflow

When Tableflow is enabled on `driver_stats`, it materializes Iceberg tables into S3 and AWS Glue catalog.
After failover to DR, query Athena / Trino against Glue DB `dr_car_rides_dr`.
