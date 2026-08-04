# Confluent Cloud — DR Car Rides

## Goal

Provision **DR** Confluent Cloud environment/cluster (primary reuses existing `j9r-env` / `j9r-kafka`), run an active/active Flink pipeline on car-ride events, mirror topics with Cluster Linking, **replicate schemas with Schema Linking**, materialize aggregates with Tableflow/Glue, and practice soft + promote failover with sequence-based loss assessment.

![](../docs/cc-raw-to-sink.drawio.png)

## Status

Requires CC org + AWS credentials. Dual Standard clusters, dual Stream Governance, and Tableflow incur cost.

## Implementation approach

| Phase | Location | What |
|-------|----------|------|
| 0 — Primary catalog | [`IaC/import-j9r-env/`](./IaC/import-j9r-env/) | Imported `j9r-env` / `j9r-kafka` + outputs for remote state |
| 1 — IaC | [`IaC/`](./IaC/) | Terraform (incremental): reuse primary; create DR env/Kafka/SR/SAs/Flink pools first |
| 2 — App | [`flink-sql/`](./flink-sql/) | Flink DDL/DML via tools based on confluent-sql python library |
| 3 - Lakehouse | | TableFlow and AWS resources |
| 4 - Run continuous producer | [`../python/`](../python/) | Continuous producer + `assess_loss` |
| Ops | [`scripts/`](./scripts/) | Soft/promote failover, failback (incl. schema reverse), `export-env.sh` (Kafka + SR per site) |
| Data | |


### High-level demonstration flow

1. Apply Phase 1 Terraform (`cccloud/IaC/`) — dual env, clusters, link, mirrors, Schema Linking, AWS.
2. Deploy primary Flink + Tableflow (`cccloud/flink-sql/`).
3. Run continuous producer (`python/produce_rides.py`) against primary Kafka + primary SR.
4. Soft or promote failover (`cccloud/scripts/`) — retarget producer to DR Kafka + DR SR.
5. Assess loss (`python/assess_loss.py`).


## Prerequisites

- Terraform `>= 1.3`, Confluent Cloud API key with org access
- Confluent Cloud [terraform provider](https://registry.terraform.io/providers/confluentinc/confluent/latest) - version 2.81.0+
- Existing `j9r-env` primary (imported under `IaC/import-j9r-env/`; apply that stack first so outputs exist)
- AWS credentials (S3 + Glue + IAM for Tableflow BYOB)
- Python 3.11+ with `uv` or `pip` (`confluent-kafka[schema-registry]`, `pydantic`)
- Optional: Confluent CLI for promote / statement stop / exporter pause

## How to run

### 1. Build DR site

* Get existing infrastructure data
```bash
cd IaC/import-j9r-env 
cp terraform.tfvars.example terraform.tfvar
# modify variables for your own primary environment
terraform init
terraform apply 
cd ..
```

* Create secondary region environment, Kafka cluster and schema registry

```sh 
cp terraform.tfvars.example terraform.tfvars
terraform init && terraform apply
terraform output -json > ../scripts/iac-outputs.json
```

![](../docs/DR-env-clust-cp.png)


### 2. Deploy Flink statements (active/active)

```bash
cd ../flink-sql
# one time:
make sync

# Primary only (default)
make deploy

# DR / secondary only
make deploy SITE=dr
# or: make deploy SITE=secondary

# Both sites (active/active prep)
make deploy-both
```

You should see statements created on each site, for example:

```sh
Creating statement: flink-sql-facts-ddl-driver-stats
Creating statement: flink-sql-seed-ddl-rides-raw
Creating statement: flink-sql-dims-pipeline-rides-clean
Creating statement: flink-sql-facts-pipeline-driver-stats
```

Single groups: `make deploy-ddl SITE=dr`, `make undeploy SITE=secondary`, `make undeploy-both`.

### 3. Produce rides (primary Kafka + primary SR)

```bash
source ../scripts/export-env.sh primary
cd ../../python
uv sync
uv run produce_rides.py --interval 0.5
```


###

Verify Schema Linking: DR SR mode is `IMPORT`, exporter `schema_exporter_name` is running.

### 4. Soft failover

```bash
cd ../cccloud/scripts
./failover-soft.sh
# Pause exporter; set DR SR to READWRITE before new registrations if needed
source ./export-env.sh dr
cd ../../python && uv run produce_rides.py --interval 0.5
uv run assess_loss.py --producer-log /tmp/dr-car-rides-seq.log \
  --pre-failover-max-seq <N> --post-mirror-max-seq <M>
```

### 5. Promote failover (optional)

```bash
./failover-promote.sh
```

## Catalog cutover

After DR Tableflow is enabled, query Athena against Glue DB `dr_car_rides_dr`. Do not assume Iceberg continuity from the primary bucket without separate storage replication.
