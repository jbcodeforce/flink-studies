# DR Car Rides — Phase 1 IaC

Provisions **two** Confluent environments (primary + DR) with Kafka clusters, Flink pools, Schema Registries, Schema Linking, bidirectional Cluster Linking, mirror topics, dual-region S3/Glue, and Tableflow provider integration per env.

## Apply

```bash
cp terraform.tfvars.example terraform.tfvars
export CONFLUENT_CLOUD_API_KEY=...
export CONFLUENT_CLOUD_API_SECRET=...
terraform init && terraform apply
terraform output -json > ../scripts/iac-outputs.json
```

## Schema Linking

| Resource | Role |
|----------|------|
| `confluent_schema_registry_cluster_mode.dr_import` | DR SR global mode = `IMPORT` (`force = true`) |
| `confluent_schema_exporter.primary_to_dr` | Replicates subjects `:*:` primary → DR |

See [`schema-linking.tf`](./schema-linking.tf) and [DESIGN.md](../../DESIGN.md). On failover, pause the exporter and set DR SR to `READWRITE` before clients need to register new schema versions.

## Notes

- After creating provider integrations, set `confluent_external_id` from the Confluent UI and re-apply to harden IAM trust (same pattern as `cc-cdc-tx-demo`).
- Mirror topics are created on the DR cluster; do not create the same topic names locally on DR.
- Tableflow PI is created in **both** environments (shared IAM role, regional buckets).
