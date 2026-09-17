# Disaster Recovery Car Rides Demo — Agent Instructions

## Overview
This directory (`e2e-demos/dr-car-rides`) implements an end-to-end Disaster Recovery (DR) demonstration and study using a real-time car-rides streaming pipeline.

The demonstration illustrates multi-region disaster recovery for streaming data architectures, including:
1. Active/Passive Kafka replication via Cluster Linking.
2. Schema replication via Schema Linking in `IMPORT` mode to preserve Schema IDs.
3. Stateful and stateless Flink SQL pipelines deployed across primary and DR regions.
4. Data lakehouse materialization with Confluent Tableflow (Iceberg / AWS Glue).
5. Controlled failover (soft failover), ungraceful failover (promote failover), and failback procedures.
6. Sequence-based RPO and processing gap loss assessment (`assess_loss.py`).

---

## Architecture & Directory Layout

```
e2e-demos/dr-car-rides/
├── README.md               # Main DR architecture, scenarios, and cross-platform roadmap
├── dr-demo-plan.md         # Implementation plan & status
├── ccloud/                 # Confluent Cloud implementation
│   ├── IaC/                # Terraform for primary (import) and secondary/DR environments
│   ├── flink-sql/          # Flink SQL DDL/DML and deploy_manifest.json
│   ├── scripts/            # Failover, failback, and environment configuration scripts
│   └── README.md           # Step-by-step Confluent Cloud demonstration guide
├── python/                 # Platform-agnostic producer & loss assessment tooling
│   ├── produce_rides.py    # Generates synthetic ride events with sequence IDs
│   ├── assess_loss.py      # Evaluates RPO & message gap via sequence IDs
│   └── pyproject.toml      # uv-managed dependencies
├── cp-flink/                     # (Future) Confluent Platform DR implementation
└── oss/                    # (Future) Pure Apache Kafka + Apache Flink DR implementation
```

---

## Target-Specific Responsibilities

### `ccloud/` (Confluent Cloud)
- **`ccloud/IaC/`**: Uses Terraform to manage primary and DR resources:
  - `import-j9r-env/`: Imports existing primary environment (`j9r-env` / `j9r-kafka`).
  - `confluent.tf`: Provisions DR environment, DR Kafka cluster, Flink compute pools, service accounts, and provider integrations.
  - `cluster-link.tf`: Configures destination-initiated Cluster Linking from primary to DR.
  - `schema-linking.tf`: Configures DR Schema Registry in `IMPORT` mode and sets up schema exporter.
  - `aws.tf`: S3 buckets and Glue Catalogs for Tableflow Iceberg tables.
- **`ccloud/flink-sql/`**: Contains DDL (`rides_raw`, `rides_clean`, `driver_stats`) and DML transformations deployed via `Makefile` and `deploy_manifest.json`.
  - Deployment uses shared tools from `code/flink-sql/tools` via `make deploy SITE=primary` or `make deploy SITE=dr`.
- **`ccloud/scripts/`**:
  - `export-env.sh <primary|dr>`: Exports cluster connection, REST endpoints, Schema Registry credentials, and Flink metadata for shell sessions.
  - `failover-soft.sh`: Graceful failover (stop primary Flink DML, set DR SR to `READWRITE`, deploy DR Flink, retarget producer).
  - `failover-promote.sh`: Ungraceful/mirror-promote failover.
  - `failback.sh`: Step-by-step failback and reverse schema sync.

### `python/` (Platform-Agnostic Tools)
- Managed with `uv`.
- Must remain platform-agnostic so the same tools work against Confluent Cloud, Confluent Platform, or Apache Kafka.
- Producer does not auto-register schemas in Schema Registry by default; it uses `use.latest.version` aligned with Flink-created schemas.
- Supports sequence numbers (`seq`) in every event payload for loss measurement.

---

## Key DR Principles & Conventions

1. **Schema ID Preservation**: DR Schema Registry is initialized in `IMPORT` mode and kept synced with primary Schema Registry using Schema Exporters. This ensures schema IDs match between primary and DR clusters.
2. **Cluster Linking**: Mirror topics in DR receive mirrored events from primary source topics (`rides_raw`).
3. **Flink Deployment**:
   - In active/passive: Primary Flink runs DML. On failover, DR Flink statements are deployed with `earliest-offset` startup.
   - Statement names follow the manifest convention: `flink-sql-dims-pipeline-rides-clean`, `flink-sql-facts-pipeline-driver-stats`.
4. **Environment Isolation**: Never mix primary and DR environment variables in the same shell session. Always use `source ccloud/scripts/export-env.sh <site>`.
