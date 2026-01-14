# Terraform Configuration for txp_dim_customers Flink Statements

This Terraform configuration deploys Flink SQL statements (DDL and DML) for the `txp_dim_customers` dimension table.

## Overview

The configuration:
- Reads infrastructure state from the parent IaC Terraform configuration
- Deploys a DDL statement to create the `txp_dim_customers` table
- Deploys a DML statement to insert data into the table
- References SQL files from the `../sql-scripts/` directory

## Prerequisites

1. The parent IaC infrastructure must be deployed first (in `../../../IaC/`)
2. Terraform state file must exist at the path specified in `variables.tf` (default: `../../../IaC/terraform.tfstate`)
3. Confluent Cloud API credentials must be available

## Setup

### Environment Variables

Set Confluent Cloud API credentials:

```bash
export TF_VAR_confluent_cloud_api_key="<your-api-key>"
export TF_VAR_confluent_cloud_api_secret="<your-api-secret>"
```

Or create a `terraform.tfvars` file:

```hcl
confluent_cloud_api_key    = "<your-api-key>"
confluent_cloud_api_secret = "<your-api-secret>"
```

### Terraform

```bash
cd terraform
terraform init

terraform plan

terraform apply
```

### Destroy Resources

Remove the Flink statements:

```bash
terraform destroy
```

## Configuration

### Variables

- `confluent_cloud_api_key`: Confluent Cloud API Key
- `confluent_cloud_api_secret`: Confluent Cloud API Secret
- `iac_state_path`: Path to IaC terraform state file (default: `../../../../../IaC/terraform.tfstate`)
- `cloud_region`: AWS region for Flink deployment (default: `us-east-2`)
- `statement_name_prefix`: Prefix for Flink statement names (default: `dev-usw2-txp`)
- `app_manager_service_account_id`: App Manager service account ID (optional - will try to get from IaC remote state if not set)

### Getting the Service Account ID

You can get the service account ID in one of these ways:

1. **From IaC outputs** (if IaC has been applied with the new output):
   ```bash
   cd ../../../../IaC
   terraform output -raw app_manager_service_account_id
   ```

2. **From Confluent Cloud UI**:
   - Go to Confluent Cloud → Access Management → Service Accounts
   - Find the service account with name pattern `card-tx-app-manager-*`
   - Copy the service account ID (format: `sa-xxxxxxx`)

3. **From IaC state file** (if you haven't applied the new output yet):
   ```bash
   cd ../../../../IaC
   terraform state list | grep service_account
   terraform state show <service_account_resource_name> | grep "^id"
   ```

4. **From the Flink API Key** (the API key owner is the service account):
   - The Flink API key is owned by the app_manager service account
   - You can find the service account ID in the Confluent Cloud UI by looking at the API key details

Then set it in your `terraform.tfvars`:
```hcl
app_manager_service_account_id = "sa-xxxxxxx"
```

### Resources Created

1. **DDL Statement**: Creates the `txp_dim_customers` table
   - Statement name: `{prefix}-ddl-txp-dim-customers`
   - SQL file: `../sql-scripts/ddl.txp_dim_customers.sql`

2. **DML Statement**: Inserts data into `txp_dim_customers`
   - Statement name: `{prefix}-dml-txp-dim-customers`
   - SQL file: `../sql-scripts/dml.txp_dim_customers.sql`
   - Properties: Merges base properties with `dml.txp_dim_customers.properties` if present

### Dependencies

The DML statement depends on the DDL statement being created first. Terraform automatically handles this dependency.

## Remote State

This configuration uses `terraform_remote_state` to read values from the parent IaC configuration:

- `confluent_environment_id`
- `flink_compute_pool_id`
- `kafka_cluster_id`
- `flink_api_key`
- `flink_api_secret`

Ensure the IaC state file is accessible at the configured path.

## Properties File

The DML statement can use custom properties from `../sql-scripts/dml.txp_dim_customers.properties`. The file format is:

```
key1=value1
key2=value2
# Comments start with #
```

Properties are merged with base Flink properties. If the file doesn't exist or is empty, only base properties are used.

## Troubleshooting

### State File Not Found

If you get an error about the state file not being found:

1. Verify the IaC infrastructure has been deployed
2. Check the `iac_state_path` variable matches the actual state file location
3. Use an absolute path if needed

### Statement Creation Fails

Common issues:

1. **Missing Dependencies**: Ensure the DDL statement is created before DML
2. **SQL Syntax Errors**: Validate SQL files before deployment
3. **Permissions**: Verify the API key has FlinkDeveloper role
4. **Compute Pool**: Ensure the compute pool is active and has available CFU

### Properties Not Applied

If properties from the properties file aren't being applied:

1. Check the file format (key=value, one per line)
2. Ensure no leading/trailing whitespace
3. Comments (lines starting with #) are ignored
