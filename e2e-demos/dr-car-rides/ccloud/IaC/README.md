# DR Car Rides

## Phase 1 IaC (incremental)

Reuses existing **j9r-env** / **j9r-kafka** as primary (via `import-j9r-env` remote state). Builds the DR side in iterations.

| Iteration | Flags | Creates |
|-----------|-------|---------|
| 1 (current) | all `false` | DR env, DR Kafka, SR data sources, SA role bindings + API keys, Flink pools (primary + DR) |
| 2 | `enable_cluster_link` + `enable_schema_linking` | Topics, Cluster Linking, mirrors, SR IMPORT + exporter |
| later | `enable_tableflow` | AWS S3/Glue/IAM + Tableflow provider integrations |



### 2. Apply iteration 1 (Confluent DR core)




No AWS credentials required for iteration 1 (`enable_tableflow=false` skips AWS credential validation).

`terraform destroy` on this stack does **not** destroy j9r-env / j9r-kafka / j9r SAs.



## Notes

- Demo roles reuse the imported `env-manager` SA. This stack creates API keys and role bindings on that SA.
- Iteration 2: set `enable_cluster_link = true` and `enable_schema_linking = true`, then re-apply.
- Tableflow: set `enable_tableflow = true` after AWS is ready; then set `confluent_external_id` from the Confluent UI and re-apply.
