# DR Car Rides — Phase 1 IaC

Reuses existing **j9r-env** / **j9r-kafka** as primary (via `import-j9r-env` remote state). Creates the **DR** environment and Kafka cluster, Flink pools on both sides, Schema Linking, bidirectional Cluster Linking, mirror topics, dual-region S3/Glue, and Tableflow provider integration per env.

## Apply order

### 1. Refresh import outputs (once)

```bash
cd import-j9r-env
# Requires CONFLUENT_CLOUD_API_KEY / CONFLUENT_CLOUD_API_SECRET (and SR vars if used by that stack)
terraform init
terraform apply   # writes outputs into terraform.tfstate; does not recreate j9r resources
cd ..
```

### 2. Apply DR demo stack

```bash
cp terraform.tfvars.example terraform.tfvars
export CONFLUENT_CLOUD_API_KEY=...
export CONFLUENT_CLOUD_API_SECRET=...
terraform init && terraform apply
terraform output -json > ../scripts/iac-outputs.json
```

Defaults: `primary_region = us-west-2` (j9r-kafka), `dr_region = us-east-1`.

`terraform destroy` on this stack does **not** destroy j9r-env / j9r-kafka / j9r SAs (data sources + remote state only).

## Schema Linking

| Resource | Role |
|----------|------|
| `confluent_schema_registry_cluster_mode.dr_import` | DR SR global mode = `IMPORT` (`force = true`) |
| `confluent_schema_exporter.primary_to_dr` | Replicates subjects `:*:` primary → DR |

See [`schema-linking.tf`](./schema-linking.tf) and [DESIGN.md](../../DESIGN.md). On failover, pause the exporter and set DR SR to `READWRITE` before clients need to register new schema versions.

## Notes

- Primary SA mapping: app manager → `j9r-env-manager`, Flink → `j9r-flink-app`, producer → `j9r-kafka-mgr`. Demo creates new API keys and role bindings on those SAs.
- After creating provider integrations, set `confluent_external_id` from the Confluent UI and re-apply to harden IAM trust (same pattern as `cc-cdc-tx-demo`).
- Mirror topics are created on the DR cluster; do not create the same topic names locally on DR.
- Tableflow PI is created in **both** environments (shared IAM role, regional buckets).
