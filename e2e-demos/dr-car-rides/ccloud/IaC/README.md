# DR Car Rides

## Phase 1 IaC (incremental)

Reuses existing **j9r-env** / **j9r-kafka** as primary (via `import-j9r-env` remote state). Builds the DR side in iterations.

| Iteration | Flags | Creates |
|-----------|-------|---------|
| 1 (current) | all `false` | DR env, DR Kafka, SR data sources, SA role bindings + API keys, Flink pools (primary + DR) |
| 2 | `enable_cluster_link` + `enable_schema_linking` | Topics, Cluster Linking, mirrors, SR IMPORT + exporter |
| later | `enable_tableflow` | AWS S3/Glue/IAM + Tableflow provider integrations |

## Apply order

### 1. Refresh import outputs (once)

```bash
cd import-j9r-env
export CONFLUENT_CLOUD_API_KEY=...
export CONFLUENT_CLOUD_API_SECRET=...
terraform init && terraform apply
cd ..
```

### 2. Apply iteration 1 (Confluent DR core)

```bash
cp terraform.tfvars.example terraform.tfvars   # or edit existing tfvars
# ensure: enable_cluster_link=false, enable_schema_linking=false, enable_tableflow=false
terraform init && terraform apply
terraform output -json > ../scripts/iac-outputs.json
```

Defaults: `primary_region = us-west-2` (j9r-kafka), `dr_region = us-east-1`.

No AWS credentials required for iteration 1 (`enable_tableflow=false` skips AWS credential validation).

`terraform destroy` on this stack does **not** destroy j9r-env / j9r-kafka / j9r SAs.

## Notes

- Demo roles reuse the imported `env-manager` SA. This stack creates API keys and role bindings on that SA.
- Iteration 2: set `enable_cluster_link = true` and `enable_schema_linking = true`, then re-apply.
- Tableflow: set `enable_tableflow = true` after AWS is ready; then set `confluent_external_id` from the Confluent UI and re-apply.
