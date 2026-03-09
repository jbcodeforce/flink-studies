# Package event cutoff – Confluent Cloud

## Goal

Run the package morning cutoff demo (expected_delivery change, 11:30 cutoff, ETA computation) on Confluent Cloud using Confluent CLI to deploy Flink SQL statements. Same business logic as the root demo; this folder contains CC-specific automation and optional Terraform.

## Status

Ready. Requires Confluent Cloud environment with Kafka cluster and Flink compute pool. Use case 3 (Compute ETA) requires the `estimate_delivery` UDF to be registered in the Flink catalog (see [../eta_udf/](../eta_udf/)).

## Implementation approach

- **IaC:** Optional Terraform in `IaC/` for Confluent Cloud resources (compute pool, etc.). Flink statement deployment is done via shell scripts and Confluent CLI, not Terraform, for the three use cases.
- **Application logic:** Scripts in this folder (`run_use_case_1.sh`, `run_use_case_2.sh`, `run_use_case_3.sh`) deploy DDL and DML to the Flink workspace. They use shared SQL and tests from the demo root: `../sql-scripts/`, `../tests/`.
- **UDF:** Use case 3 uses a table function `estimate_delivery`; see [../eta_udf/](../eta_udf/) for a Python reference implementation and registration notes.

## How to run

### Prerequisites

- Confluent Cloud: Kafka cluster, Flink compute pool, and `confluent` CLI logged in.
- Environment variables (or defaults in `package_event_cutoff_lib.sh`): `FLINK_ENVIRONMENT`, `FLINK_CONTEXT`, `FLINK_COMPUTE_POOL`, `FLINK_DATABASE`; optionally `CLOUD`, `REGION`, `KAFKA_CLUSTER`.

### Steps

1. **Set environment** (from repo root or this folder):
   ```sh
   export FLINK_DATABASE='your-kafka-cluster-name'
   export FLINK_COMPUTE_POOL='your-compute-pool-id'
   export FLINK_ENVIRONMENT='your-environment-id'
   ```

2. **Use case 1 – expected_ts change pipeline**
   ```sh
   ./run_use_case_1.sh
   ```

3. **Use case 2 – cutoff-time pipeline**
   ```sh
   ./run_use_case_2.sh
   ```

4. **Use case 3 – Compute ETA** (requires `estimate_delivery` UDF registered; run use case 1 first for extended schema)
   ```sh
   ./run_use_case_3.sh
   ```

### Optional: Terraform

To provision or manage Confluent Cloud resources with Terraform, use `IaC/`:

- Copy `IaC/terraform.tfvars.example` to `IaC/terraform.tfvars` and set your values.
- Run `terraform init` and `terraform apply` from `IaC/`. Note: the current `flink.tf` may reference a different pipeline; the three use cases above are deployed via the shell scripts, not this Terraform.
