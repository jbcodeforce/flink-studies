# j9r-env Base Infrastructure

This folder contains Terraform definitions for the j9r-env Confluent Cloud environment. This serves as the base infrastructure for Flink applications.

For detailed documentation on Terraform with Confluent Cloud, see the [Terraform chapter](https://jbcodeforce.github.io/flink-studies/coding/terraform/) in the flink-studies documentation.

## Resources Created

| Resource | Name | Purpose |
|----------|------|---------|
| Environment | j9r-env | Base environment with Advanced governance |
| Service Account | j9r-env-manager | EnvironmentAdmin role |
| Kafka Cluster | j9r-kafka | Standard cluster, single AZ |
| Kafka API Key | standard-kafka-api-key | |
| Flink API Key | flink-developer-sa-flink-api-key | |
| Schema Registry | (auto-provisioned) | Essentials package |
| Schema Registry API Key | env-manager-schema-registry-api-key | |
| Service Account | j9r-fd-sa | FlinkDeveloper for deploying statements |
| Compute Pool | dev-j9r-pool | Main compute pool (50 CFU) |
| Compute Pool | data-generation | For test data generation |

## File Structure

```
├── main.tf             # Provider configuration
├── variables.tf        # Variable definitions
├── terraform.tfvars    # Variable values
├── env.tf              # Environment + env-manager SA
├── kafka.tf            # Kafka cluster + app-manager SA
├── schema_registry.tf  # Schema Registry data source + API key
├── flink.tf            # Flink service accounts and role bindings
├── pools.tf            # Flink compute pools
└── outputs.tf          # All outputs organized by resource
```

## Prerequisites

1. Create Confluent Cloud API keys with OrganizationAdmin role
2. Set environment variables:

```sh
export TF_VAR_confluent_cloud_api_key="<your-api-key>"
export TF_VAR_confluent_cloud_api_secret="<your-api-secret>"
```

## Deployment

```sh
terraform init
terraform plan
terraform apply --auto-approve
```

## Outputs

After deployment, retrieve configuration values:

```sh
terraform output
```

Key outputs for Flink statement deployments:
- `flink_api_key_id` / `flink_api_key_secret` - Flink API credentials
- `flink_dev-j9r-pool_id` - Default compute pool ID
- `flink_rest_endpoint` - Flink REST endpoint
- `env_display_name` - Flink catalog name
- `kafka_cluster_display_name` - Flink database name

### Viewing and reusing API secrets

Secrets are stored in Terraform state and exposed as sensitive outputs. To print a single secret for use in another application:

```sh
# Kafka (env-manager service account)
terraform output -raw kafka_api_key_id
terraform output -raw kafka_api_key_secret

# Schema Registry
terraform output -raw schema_registry_api_key_id
terraform output -raw schema_registry_api_key_secret

# Flink (flink-developer-sa)
terraform output -raw flink_api_key_id
terraform output -raw flink_api_key_secret
```

Use in another application (examples):

```sh
# Export as environment variables
export KAFKA_API_KEY=$(terraform -chdir=path/to/cc-terraform output -raw kafka_api_key_id)
export KAFKA_API_SECRET=$(terraform -chdir=path/to/cc-terraform output -raw kafka_api_key_secret)
```

Or reference this stack's outputs from another Terraform configuration using a [remote state data source](https://developer.hashicorp.com/terraform/language/state/remote-state-data) and `terraform_remote_state`; then use the output attributes (e.g. `outputs.kafka_api_key_secret`) in that configuration. Keep state backend access restricted and never commit state or raw outputs to version control.
