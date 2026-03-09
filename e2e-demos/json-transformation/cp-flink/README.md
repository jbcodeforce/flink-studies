# Json transformation – Confluent Platform Flink

## Goal

Run the truck rental JSON transformation (raw-orders + raw-jobs → nested OrderDetails) on Confluent Platform with Flink: Table API Java application or pure SQL, deployed via Kubernetes (CMF/CFK). Same business logic as the [cccloud/](../cccloud/) variant.

## Status

Ready. Requires Confluent Platform on Kubernetes (Colima or similar), Confluent Manager for Flink (CMF), Kafka, and catalog. Producer for test data: [../src/producer/](../src/producer/).

## Implementation approach

- **No Terraform:** K8s manifests in `k8s/` (topics, schemas, RBAC, FlinkApplication, compute pool, catalog). Deploy with `kubectl` and root Makefile targets (e.g. `make create_catalog`, `make expose_services`).
- **Application logic:** Flink Table API Java app in `table_api/` (build with Maven, image with Docker). Equivalent SQL in `sqls/`. Deploy Flink application via `make deploy` from this folder or Confluent CLI.
- **Shared:** Producer and schemas at demo root: [../src/producer/](../src/producer/), [../src/schemas/](../src/schemas/).

## How to run

### Prerequisites

- Confluent Platform on K8s (see root [README.md](../README.md) and [../../deployment/k8s/cp-flink/](../../deployment/k8s/cp-flink/)).
- From demo root: create catalog, expose services (`make create_catalog`, `make expose_services`).

### Steps

1. **From demo root:** Create SQL catalog and expose CMF/Kafka (see root README).
2. **From this folder (`cp-flink/`):**
   - Build and deploy Flink app: `make build` then `make deploy`.
   - Or use Flink SQL shell: `make start_flink_shell`, then run DDL/DML from `sqls/` or the root README “Flink SQL processing” section.
3. Produce test data from [../src/producer/](../src/producer/) (CLI or API).
4. Verify: `select * from order_details` in Flink shell or UI.
5. Cleanup: `make undeploy` from this folder; root Makefile for full teardown.

See root [README.md](../README.md) for full flow, Flink SQL examples, and producer environment variables.
