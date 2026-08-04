# Import catalog — j9r primary only

Imports a single environment (`j9r-env`), its Kafka cluster (`j9r-kafka`), and one service account. Outputs feed the parent DR IaC via `terraform_remote_state`.

| Resource | Terraform address | ID (default) |
|----------|-------------------|--------------|
| Environment | `confluent_environment.env` | `env-yk3jm6` |
| Kafka cluster | `confluent_kafka_cluster.standard` | `lkc-7v233w` |
| Service account | `confluent_service_account.env-manager` | `sa-111z1z` |

IDs are set in `variables.tf` / `import.tf`.

## Apply (import)

```bash
export CONFLUENT_CLOUD_API_KEY=...
export CONFLUENT_CLOUD_API_SECRET=...
# Optional SR vars if your provider config requires them
terraform init
terraform plan    # should show import of the 3 resources
terraform apply
terraform output
```

If you previously imported the org-wide catalog, remove the old state first:

```bash
rm -f terraform.tfstate terraform.tfstate.backup
terraform apply
```

State is gitignored. Parent DR IaC reads `import-j9r-env/terraform.tfstate`.
