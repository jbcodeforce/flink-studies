# DR Car Rides — Active/Passive Disaster Recovery Demo

The goal it to demonstrate Confluent Cloud **active/passive** multi-region disaster recovery for a data streaming processing (DSP): 

Provision a DR Confluent Cloud environment alongside existing **j9r-env** / **j9r-kafka** (primary), run an active/passive Flink pipeline on car-ride events, mirror topics with Cluster Linking, replicate schemas with Schema Linking, materialize aggregates with Tableflow/Glue, and practice soft + promote failover with sequence-based loss assessment.

## Supported deployments

| Deployment | Path | Status |
|------------|------|--------|
| Confluent Cloud | [`cccloud/`](./cccloud/) | Ready (IaC + Flink SQL + scripts) |
| OSS Flink | — | Not yet implemented |
| CP Flink | — | Not fully yet implemented; see [`savepoint-demo`](../savepoint-demo/) for CP savepoint DR |

## What is covered

- Dual-region Kafka across **two environments** with bidirectional Cluster Linking
- Schema Linking: DR SR in IMPORT + exporter primary → DR (schema ID integrity)
- Flink runs as independent regional jobs (no cross-region cluster)
- Source topics replicated: rebuild from earliest + measure loss with `seq`
- Soft vs promote failover runbooks (Kafka + schemas + Tableflow/Glue)

## Confluent Cloud

![](./docs/raw-to-sink.drawio.png)

### Steady state

- **Primary** reuses existing `j9r-env` / `j9r-kafka` (`us-west-2`); **DR** is a new environment/cluster (`us-east-1`). Each side has its own Schema Registry (required for Schema Linking on Confluent Cloud).
- Producer writes to primary Kafka + primary SR.
- Flink runs only on primary.
- Tableflow on `driver_stats` → primary S3 + Glue; DR has its own Tableflow provider integration for failover.
- Bidirectional Cluster Linking mirrors `rides_raw`, `rides_clean`, `driver_stats`.
- **Schema Linking:** DR SR mode = `IMPORT`; `confluent_schema_exporter` replicates all subjects from primary → DR so schema IDs match after failover.

### Failover

- Soft / promote as before for Kafka + Flink.
- Schema: pause exporter; set DR SR to `READWRITE` before producers/Flink need to register new versions; existing IDs already imported remain valid.
- Failback: reverse exporter (DR → primary with primary in `IMPORT`), then restore steady-state primary→DR exporter.

### DSP component map

| DSP component | Demo artifact |
|---------------|---------------|
| Kafka topics | `rides_raw`, `rides_clean`, `driver_stats` + Cluster Link mirrors |
| Schemas | Primary + DR Schema Registry; Schema Linking exporter (`:*:`) |
| Kafka connectors | N/A — native producer (not Connect) |
| Flink statements | Stage 1 filter/transform; stage 2 driver tumble agg |
| Tableflow | Enabled on `driver_stats` (primary; DR on failover) |
| Catalog | Glue DBs `dr_car_rides_primary` / `dr_car_rides_dr` |
| Iceberg | Per-region S3 BYOB buckets |

### High-level demonstration flow

1. Apply Phase 1 Terraform (`cccloud/IaC/`) — dual env, clusters, link, mirrors, Schema Linking, AWS.
2. Deploy primary Flink + Tableflow (`cccloud/flink-sql/`).
3. Run continuous producer (`python/produce_rides.py`) against primary Kafka + primary SR.
4. Soft or promote failover (`cccloud/scripts/`) — retarget producer to DR Kafka + DR SR.
5. Assess loss (`python/assess_loss.py`).

See [`ccloud/README.md`](./ccloud/README.md) for ordered steps.

## Confluent Platform

## Apache Flink and Kafka