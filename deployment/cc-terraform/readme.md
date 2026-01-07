# j9r-env Base Infrastructure

This folder contains Terraform definitions for the j9r-env Confluent Cloud environment. This serves as the base infrastructure for Flink applications.

For detailed documentation on Terraform with Confluent Cloud, see the [Terraform chapter](https://jbcodeforce.github.io/flink-studies/coding/terraform/) in the flink-studies documentation.

## Resources Created

| Resource | Name | Purpose |
|----------|------|---------|
| Environment | j9r-env | Base environment with Advanced governance |
| Service Account | j9r-env-manager | EnvironmentAdmin role |
| Kafka Cluster | j9r-kafka | Standard cluster, single AZ |
| Schema Registry | (auto-provisioned) | Advanced package |
| Service Account | j9r-app-manager | CloudClusterAdmin on Kafka |
| Service Account | j9r-flink-app | Runtime principal for Flink statements |
| Service Account | j9r-fd-sa | FlinkDeveloper for deploying statements |
| Compute Pool | default | Main compute pool (50 CFU) |
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
- `flink_compute_pool_id` - Default compute pool ID
- `flink_rest_endpoint` - Flink REST endpoint
- `env_display_name` - Flink catalog name
- `kafka_cluster_display_name` - Flink database name
