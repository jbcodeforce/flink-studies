# Import catalog — j9r primary

Holds Terraform resources imported from the Confluent org, with **outputs** for the DR car-rides stack to consume via `terraform_remote_state`.

Primary resources used by the demo:

| Resource | Display name | Typical ID |
|----------|--------------|------------|
| Environment | `j9r-env` | `env-yk3jm6` |
| Kafka cluster | `j9r-kafka` | `lkc-7v233w` (us-west-2) |
| SAs | `j9r-env-manager`, `j9r-kafka-mgr`, `j9r-flink-app`, `j9r-fd-sa` | see `terraform output` |

## Refresh outputs

```bash
export CONFLUENT_CLOUD_API_KEY=...
export CONFLUENT_CLOUD_API_SECRET=...
# Plus Schema Registry vars if required by provider block in main.tf
terraform init
terraform apply
```

State file `terraform.tfstate` is gitignored. The parent DR IaC reads it at `import-j9r-env/terraform.tfstate`.
