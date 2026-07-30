# DR Car Rides — Active/Passive Disaster Recovery Demo

Demonstrate Confluent Cloud **active/passive** multi-region DR for a data streaming processing (DSP): car-ride events → Flink (stateless + stateful) → Tableflow / Iceberg / Glue, with **Cluster Linking**, **Schema Linking** (dual Schema Registry), and measurable RPO via a monotonic `seq`.

**Design:** [DESIGN.md](./DESIGN.md)  
**Cookbook:** [Disaster Recovery & Multi-Region](../../docs/cookbook/cluster_mgt.md#3-disaster-recovery--multi-region-strategies)

## Supported deployments

| Deployment | Path | Status |
|------------|------|--------|
| Confluent Cloud | [`cccloud/`](./cccloud/) | Ready (IaC + Flink SQL + scripts) |
| OSS Flink | — | Out of scope (v1) |
| CP Flink | — | Out of scope (v1); see [`savepoint-demo`](../savepoint-demo/) for CP savepoint DR |

## What you will learn

- Dual-region Kafka across **two environments** with bidirectional Cluster Linking
- Schema Linking: DR SR in IMPORT + exporter primary → DR (schema ID integrity)
- Why Flink runs as independent regional jobs (no cross-region cluster)
- Hybrid offset strategy on CC: rebuild from earliest + measure loss with `seq`
- Soft vs promote failover runbooks (Kafka + schemas + Tableflow/Glue)

## DSP component map

| DSP component | Demo artifact |
|---------------|---------------|
| Kafka topics | `rides_raw`, `rides_clean`, `driver_stats` + Cluster Link mirrors |
| Schemas | Primary + DR Schema Registry; Schema Linking exporter (`:*:`) |
| Kafka connectors | N/A — native producer (not Connect) |
| Flink statements | Stage 1 filter/transform; stage 2 driver tumble agg |
| Tableflow | Enabled on `driver_stats` (primary; DR on failover) |
| Catalog | Glue DBs `dr_car_rides_primary` / `dr_car_rides_dr` |
| Iceberg | Per-region S3 BYOB buckets |

## High-level flow

1. Apply Phase 1 Terraform (`cccloud/IaC/`) — dual env, clusters, link, mirrors, Schema Linking, AWS.
2. Deploy primary Flink + Tableflow (`cccloud/flink-sql/`).
3. Run continuous producer (`python/produce_rides.py`) against primary Kafka + primary SR.
4. Soft or promote failover (`cccloud/scripts/`) — retarget producer to DR Kafka + DR SR.
5. Assess loss (`python/assess_loss.py`).

See [`ccloud/README.md`](./ccloud/README.md) for ordered steps.
