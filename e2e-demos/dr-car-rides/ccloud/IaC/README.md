# DR Car Rides

## Phase 1 IaC (incremental)

Reuses existing **j9r-env** / **j9r-kafka** as primary (via `import-j9r-env` remote state). Builds the DR side in iterations.

| Iteration | Flags | Creates |
|-----------|-------|---------|
| 1 (current) | all `false` | DR env, DR Kafka, SR data sources, SA role bindings + API keys, Flink pools (primary + DR) |
| 2 | `enable_cluster_link` + `enable_schema_linking` | Topics, Cluster Linking, mirrors, SR IMPORT + exporter |
| later | `enable_tableflow` | AWS S3/Glue/IAM + Tableflow provider integrations |



### 1. Import Primary Environment (Once)

First, import and output the existing primary environment:

```bash
cd import-j9r-env
export CONFLUENT_CLOUD_API_KEY=...
export CONFLUENT_CLOUD_API_SECRET=...
terraform init
terraform apply
cd ..
```

### 2. Apply Iteration 1 (Confluent DR Core)

Configure `terraform.tfvars`:

```hcl
enable_cluster_link   = false
enable_schema_linking = false
enable_tableflow      = false
primary_region        = "us-west-2"
dr_region             = "us-east-1"
```

Apply Terraform:

```bash
terraform init
terraform apply
terraform output -json > ../scripts/iac-outputs.json
```

No AWS credentials required for iteration 1 (`enable_tableflow=false` skips AWS credential validation).
`terraform destroy` on this stack does **not** destroy `j9r-env` / `j9r-kafka` / primary SAs.

### 3. Apply Iteration 2 (Cluster Linking & Schema Linking)

Once the primary and DR clusters are provisioned, enable Cluster Linking and Schema Linking in `terraform.tfvars`:

```hcl
enable_cluster_link   = true
enable_schema_linking = true
```

Apply again to create source topics, cluster link, mirror topics, and the schema exporter with DR Schema Registry in `IMPORT` mode:

```bash
terraform apply
terraform output -json > ../scripts/iac-outputs.json
```

### 4. Apply Iteration 3 (Optional: Tableflow with AWS S3 + Glue)

To enable Tableflow integration:
1. Set AWS credentials (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION`).
2. Set `enable_tableflow = true` in `terraform.tfvars`.
3. Apply Terraform:
   ```bash
   terraform apply
   terraform output -json > ../scripts/iac-outputs.json
   ```

## Notes

- Demo roles reuse the imported `env-manager` SA. This stack creates API keys and role bindings on that SA.
- Iteration 2: set `enable_cluster_link = true` and `enable_schema_linking = true`, then re-apply.
- Tableflow: set `enable_tableflow = true` after AWS is ready; then set `confluent_external_id` from the Confluent UI and re-apply.
