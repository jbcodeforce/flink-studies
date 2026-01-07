# Terraform for Confluent Cloud Flink

???- info "Version"
    * Created November 2024
    * Updated January 2026

This guide covers using Terraform to deploy and manage Confluent Cloud infrastructure for Flink applications.

## Overview

The [Confluent Terraform Provider](https://docs.confluent.io/cloud/current/clusters/terraform-provider.html) enables infrastructure-as-code management for Confluent Cloud resources including environments, Kafka clusters, Schema Registry, Flink compute pools, and Flink SQL statements.

???+ info "Core Principles"
    When running `terraform apply`, Terraform calculates differences between the current state (tracked in its state file) and the desired state, then applies only necessary changes. This enables incremental building of infrastructure.

    The `terraform plan` command performs the following steps by default: 

    * It first runs a refresh operation to update its in-memory state with the actual, current configuration of your remote infrastructure by making API calls to the provider.
    * It then compares this updated state with the desired state defined in your local Terraform configuration files (.tf files).
    * Finally, it outputs a set of proposed changes (add, change, or destroy) required to make the running infrastructure match your configuration files. 

    For Confluent Cloud, start with an environment, service account, and role binding, then add resources over time. Terraform automatically determines the correct order of operations based on resource dependencies.

    For managing different stages (development, staging, production), use separate configurations with dedicated state files.

**Key Resources:**

* [Confluent Terraform Provider Documentation](https://docs.confluent.io/cloud/current/clusters/terraform-provider.html)
* [Sample Project Tutorial](https://registry.terraform.io/providers/confluentinc/confluent/latest/docs/guides/sample-project)
* [Configuration Examples](https://github.com/confluentinc/terraform-provider-confluent/tree/master/examples/configurations)

## Prerequisites

### Terraform CLI

Install the latest [Terraform CLI](https://developer.hashicorp.com/terraform/install):

```sh
terraform version
```

### Confluent Cloud API Keys

Create API keys with OrganizationAdmin role at [confluent.cloud/settings/api-keys](https://confluent.cloud/settings/api-keys).

For production, use service account keys rather than user keys. Create a service account for the Terraform runner and assign the OrganizationAdmin role following the [RBAC guide](https://docs.confluent.io/cloud/current/access-management/access-control/cloud-rbac.html#add-a-role-binding-for-a-user-or-service-account).

List existing keys:

```sh
confluent api-key list | grep <cc_userid>
```

### Environment Variables

Export credentials as environment variables:

```sh
export TF_VAR_confluent_cloud_api_key="<your-api-key>"
export TF_VAR_confluent_cloud_api_secret="<your-api-secret>"
```

Do not commit `terraform.tfstate` or environment variable files to git.

## Provider Configuration

Create `main.tf` with the Confluent provider:

```terraform
terraform {
  required_providers {
    confluent = {
      source  = "confluentinc/confluent"
      version = "2.57.0"
    }
  }
}

provider "confluent" {
  cloud_api_key    = var.confluent_cloud_api_key
  cloud_api_secret = var.confluent_cloud_api_secret
}

data "confluent_organization" "my_org" {}

data "confluent_flink_region" "flink_region" {
  cloud  = var.cloud_provider
  region = var.cloud_region
}
```

Define variables in `variables.tf`:

```terraform
variable "confluent_cloud_api_key" {
  description = "Confluent Cloud API Key"
  type        = string
  sensitive   = true
}

variable "confluent_cloud_api_secret" {
  description = "Confluent Cloud API Secret"
  type        = string
  sensitive   = true
}

variable "cloud_provider" {
  description = "Cloud provider (AWS, GCP, AZURE)"
  type        = string
  default     = "AWS"
}

variable "cloud_region" {
  description = "Cloud region"
  type        = string
  default     = "us-west-2"
}

variable "prefix" {
  description = "Prefix for resource names"
  type        = string
  default     = "j9r"
}
```

Initialize Terraform:

```sh
terraform init
```

## Resource Definitions

Build infrastructure incrementally following dependency order. The [deployment/cc-terraform](https://github.com/jbcodeforce/flink-studies/tree/master/deployment/cc-terraform) folder contains a complete base infrastructure example.

### Environment Layer

Create the Confluent Cloud environment with Stream Governance:

```terraform
resource "confluent_environment" "env" {
  display_name = "${var.prefix}-env"

  stream_governance {
    package = "ADVANCED"
  }
}

resource "confluent_service_account" "env-manager" {
  display_name = "${var.prefix}-env-manager"
  description  = "Service account to manage ${var.prefix} environment"
  depends_on   = [confluent_environment.env]
}

resource "confluent_role_binding" "env-admin" {
  principal   = "User:${confluent_service_account.env-manager.id}"
  role_name   = "EnvironmentAdmin"
  crn_pattern = confluent_environment.env.resource_name
}
```

**Importing existing resources:**

For existing environments, use an `imports.tf` file:

```terraform
import {
  to = confluent_environment.env
  id = "env-abc123"
}

import {
  to = confluent_service_account.env-manager
  id = "sa-xyz789"
}
```

### Kafka Layer

Create a Kafka cluster with API keys:

```terraform
resource "confluent_kafka_cluster" "standard" {
  display_name = "${var.prefix}-kafka"
  availability = "SINGLE_ZONE"
  cloud        = var.cloud_provider
  region       = var.cloud_region
  standard {}

  environment {
    id = confluent_environment.env.id
  }
}

resource "confluent_api_key" "kafka-api-key" {
  display_name = "kafka-api-key"
  description  = "Kafka API Key"
  owner {
    id          = confluent_service_account.env-manager.id
    api_version = confluent_service_account.env-manager.api_version
    kind        = confluent_service_account.env-manager.kind
  }
  managed_resource {
    id          = confluent_kafka_cluster.standard.id
    api_version = confluent_kafka_cluster.standard.api_version
    kind        = confluent_kafka_cluster.standard.kind
    environment {
      id = confluent_environment.env.id
    }
  }
}
```

Import existing Kafka cluster:

```sh
terraform import confluent_kafka_cluster.standard env-abc123/lkc-xyz789
```

### Schema Registry Layer

Schema Registry is auto-provisioned with the environment. Reference it as a data source:

```terraform
data "confluent_schema_registry_cluster" "essentials" {
  environment {
    id = confluent_environment.env.id
  }
  depends_on = [confluent_kafka_cluster.standard]
}

resource "confluent_api_key" "schema-registry-api-key" {
  display_name = "schema-registry-api-key"
  owner {
    id          = confluent_service_account.env-manager.id
    api_version = confluent_service_account.env-manager.api_version
    kind        = confluent_service_account.env-manager.kind
  }
  managed_resource {
    id          = data.confluent_schema_registry_cluster.essentials.id
    api_version = data.confluent_schema_registry_cluster.essentials.api_version
    kind        = data.confluent_schema_registry_cluster.essentials.kind
    environment {
      id = confluent_environment.env.id
    }
  }
}
```

### Flink Layer

Flink requires two service accounts with specific role bindings:

1. **flink-app** - Runtime principal for Flink statements
2. **flink-developer-sa** - Deploys Flink statements

```terraform
# Flink runtime principal
resource "confluent_service_account" "flink-app" {
  display_name = "${var.prefix}-flink-app"
  description  = "Service account as which Flink statements run"
}

resource "confluent_role_binding" "flink-app-clusteradmin" {
  principal   = "User:${confluent_service_account.flink-app.id}"
  role_name   = "CloudClusterAdmin"
  crn_pattern = confluent_kafka_cluster.standard.rbac_crn
}

resource "confluent_role_binding" "flink-app-sr-read" {
  principal   = "User:${confluent_service_account.flink-app.id}"
  role_name   = "DeveloperRead"
  crn_pattern = "${data.confluent_schema_registry_cluster.essentials.resource_name}/subject=*"
}

resource "confluent_role_binding" "flink-app-sr-write" {
  principal   = "User:${confluent_service_account.flink-app.id}"
  role_name   = "DeveloperWrite"
  crn_pattern = "${data.confluent_schema_registry_cluster.essentials.resource_name}/subject=*"
}

# Flink developer (deploys statements)
resource "confluent_service_account" "flink-developer-sa" {
  display_name = "${var.prefix}-fd-sa"
  description  = "Service account to deploy Flink statements"
}

resource "confluent_role_binding" "flink-developer" {
  principal   = "User:${confluent_service_account.flink-developer-sa.id}"
  role_name   = "FlinkDeveloper"
  crn_pattern = confluent_environment.env.resource_name
}

resource "confluent_role_binding" "flink-assigner" {
  principal   = "User:${confluent_service_account.flink-developer-sa.id}"
  role_name   = "Assigner"
  crn_pattern = "${data.confluent_organization.my_org.resource_name}/service-account=${confluent_service_account.flink-app.id}"
}

resource "confluent_api_key" "flink-api-key" {
  display_name = "flink-api-key"
  description  = "Flink API Key owned by flink-developer-sa"
  owner {
    id          = confluent_service_account.flink-developer-sa.id
    api_version = confluent_service_account.flink-developer-sa.api_version
    kind        = confluent_service_account.flink-developer-sa.kind
  }
  managed_resource {
    id          = data.confluent_flink_region.flink_region.id
    api_version = data.confluent_flink_region.flink_region.api_version
    kind        = data.confluent_flink_region.flink_region.kind
    environment {
      id = confluent_environment.env.id
    }
  }
}
```

### Flink Compute Pools

```terraform
resource "confluent_flink_compute_pool" "default" {
  display_name = "default"
  cloud        = upper(data.confluent_flink_region.flink_region.cloud)
  region       = data.confluent_flink_region.flink_region.region
  max_cfu      = 50
  environment {
    id = confluent_environment.env.id
  }
}
```

## Deploying Flink Statements

Flink SQL statements can be deployed using the `confluent_flink_statement` resource. See the [Flink Statement Resource Documentation](https://registry.terraform.io/providers/confluentinc/confluent/latest/docs/resources/confluent_flink_statement).

### Single Compute Pool Configuration

When managing a single compute pool, configure Flink parameters in the provider block:

```terraform
provider "confluent" {
  organization_id       = var.organization_id
  environment_id        = var.environment_id
  flink_compute_pool_id = var.flink_compute_pool_id
  flink_rest_endpoint   = var.flink_rest_endpoint
  flink_api_key         = var.flink_api_key
  flink_api_secret      = var.flink_api_secret
  flink_principal_id    = var.flink_principal_id
}

resource "confluent_flink_statement" "create_table" {
  statement = "CREATE TABLE orders (order_id STRING, amount DECIMAL(10,2));"
  properties = {
    "sql.current-catalog"  = var.environment_display_name
    "sql.current-database" = var.kafka_cluster_display_name
  }
  lifecycle {
    prevent_destroy = true
  }
}
```

### Multiple Compute Pools Configuration

When managing multiple compute pools, specify resources explicitly:

```terraform
resource "confluent_flink_statement" "transaction_faker" {
  organization {
    id = data.confluent_organization.my_org.id
  }
  environment {
    id = confluent_environment.env.id
  }
  compute_pool {
    id = confluent_flink_compute_pool.data-generation.id
  }
  principal {
    id = confluent_service_account.flink-app.id
  }
  rest_endpoint = data.confluent_flink_region.flink_region.rest_endpoint

  properties = {
    "sql.current-catalog"  = confluent_environment.env.display_name
    "sql.current-database" = confluent_kafka_cluster.standard.display_name
  }

  credentials {
    key    = confluent_api_key.flink-api-key.id
    secret = confluent_api_key.flink-api-key.secret
  }

  statement      = file("${path.module}/sql/create_table.sql")
  statement_name = "create-orders-table"

  lifecycle {
    prevent_destroy = true
  }
}
```

### Statement Lifecycle Management

Use the `stopped` attribute to control statement execution:

```terraform
resource "confluent_flink_statement" "streaming_job" {
  statement = "INSERT INTO sink SELECT * FROM source;"
  stopped   = false  # Set to true to stop the statement

  lifecycle {
    prevent_destroy = true
  }
}
```

For complex deployments with many statements and canary releases, consider using [shift_left_utils](https://jbcodeforce.github.io/shift_left_utils/).

## Workflow Commands

### Standard Workflow

```sh
terraform init      # Initialize provider
terraform validate  # Validate configuration
terraform plan      # Preview changes
terraform apply     # Apply changes
```

### Auto-approve for CI/CD

```sh
terraform apply --auto-approve
```

### Retrieve Outputs

```sh
terraform output
terraform output -json > outputs.json
```

### Handle 401 Errors

If you encounter 401 errors, verify the API key environment variables are set correctly.

## Resource Importer

The [Confluent Resource Importer](https://registry.terraform.io/providers/confluentinc/confluent/latest/docs/guides/resource-importer) exports existing Confluent Cloud resources to Terraform configuration files. This is useful for:

- Discovering existing resource IDs for import statements
- Generating Terraform configurations from existing infrastructure
- Cross-checking deployed resources against Terraform definitions

### Using the Importer

Create a separate folder for the importer (e.g., `importer/main.tf`):

```terraform
terraform {
  required_providers {
    confluent = {
      source  = "confluentinc/confluent"
      version = "2.57.0"
    }
  }
}

provider "confluent" {}

resource "confluent_tf_importer" "cloud_resources" {
  output_path = "${path.module}/imported_infrastructure"
  
  # Supported resource types (cannot mix Cloud and Kafka resources)
  resources = [
    "confluent_environment",
    "confluent_service_account",
    "confluent_kafka_cluster"
  ]
}
```

### Supported Resource Types

The importer supports these resource types (but Cloud and Kafka resources cannot be imported simultaneously):

| Mode | Resources |
|------|-----------|
| Cloud | `confluent_environment`, `confluent_service_account`, `confluent_kafka_cluster` |
| Kafka | `confluent_kafka_topic`, `confluent_kafka_acl`, `confluent_connector` |
| Schema | `confluent_schema` |

### Running the Importer

```sh
export CONFLUENT_CLOUD_API_KEY="<your-api-key>"
export CONFLUENT_CLOUD_API_SECRET="<your-api-secret>"

cd importer
terraform init
terraform apply -auto-approve
```

The importer creates:

- `imported_infrastructure/main.tf` - Resource definitions
- `imported_infrastructure/terraform.tfstate` - State file with resource IDs
- `imported_infrastructure/variables.tf` - Variable definitions

### Extracting Import IDs

After running the importer, extract resource IDs from the generated files:

```sh
# Find environment IDs
grep -A2 "display_name.*j9r-env" imported_infrastructure/main.tf

# Find service account IDs from state
grep -A5 "j9r" imported_infrastructure/terraform.tfstate | grep '"id"'
```

### Creating imports.tf

Use the discovered IDs to create an `imports.tf` file in your main configuration:

```terraform
import {
  to = confluent_environment.env
  id = "env-nknqp3"
}

import {
  to = confluent_kafka_cluster.standard
  id = "env-nknqp3/lkc-3mnm0m"
}

import {
  to = confluent_service_account.env-manager
  id = "sa-7vvrvw"
}

import {
  to = confluent_flink_compute_pool.default
  id = "env-nknqp3/lfcp-80r0n7"
}
```

### Cleanup

After importing resources into your main Terraform state, the importer folder can be deleted:

```sh
rm -rf importer/
```

## Iterative Development

Build Terraform manifests incrementally:

1. Add resources and variables
2. Run validation:
   ```sh
   terraform validate
   terraform plan
   terraform apply
   ```
3. Review outputs and add dependent resources
4. Repeat

This approach provides clear understanding of dependencies and makes troubleshooting straightforward.


## Adding Flink to an Existing Environment

This section covers adding Flink resources to an existing Confluent Cloud environment that already has Kafka and Schema Registry.

### Step 1: Import Existing Resources

Use the Resource Importer (see [previous section](#resource-importer)) or manually create `imports.tf` with your existing resource IDs:

```terraform
# imports.tf - Reference existing resources
import {
  to = confluent_environment.env
  id = "env-abc123"
}

import {
  to = confluent_kafka_cluster.standard
  id = "env-abc123/lkc-xyz789"
}

import {
  to = confluent_service_account.env-manager
  id = "sa-123abc"
}
```

### Step 2: Create Resource Definitions for Existing Resources

Create minimal resource blocks that match your existing infrastructure:

```terraform
# env.tf - Match your existing environment
resource "confluent_environment" "env" {
  display_name = "my-existing-env"
  stream_governance {
    package = "ADVANCED"  # or "ESSENTIALS"
  }
}

# kafka.tf - Match your existing cluster
resource "confluent_kafka_cluster" "standard" {
  display_name = "my-existing-kafka"
  availability = "SINGLE_ZONE"
  cloud        = "AWS"
  region       = "us-west-2"
  standard {}
  environment {
    id = confluent_environment.env.id
  }
}
```

### Step 3: Add Flink-Specific Resources

[See the quickstart TF sample for some examples](https://github.com/confluentinc/terraform-provider-confluent/tree/master/examples/configurations/flink-quickstart).

Create `flink.tf` with the Flink service accounts, role bindings, and API keys:

```terraform
# flink.tf - New Flink resources

# Data source for Schema Registry (already exists)
data "confluent_schema_registry_cluster" "essentials" {
  environment {
    id = confluent_environment.env.id
  }
}

# Flink runtime principal - runs Flink statements
resource "confluent_service_account" "flink-app" {
  display_name = "${var.prefix}-flink-app"
  description  = "Service account as which Flink statements run"
}

# Role bindings for flink-app
resource "confluent_role_binding" "flink-app-clusteradmin" {
  principal   = "User:${confluent_service_account.flink-app.id}"
  role_name   = "CloudClusterAdmin"
  crn_pattern = confluent_kafka_cluster.standard.rbac_crn
}

resource "confluent_role_binding" "flink-app-sr-read" {
  principal   = "User:${confluent_service_account.flink-app.id}"
  role_name   = "DeveloperRead"
  crn_pattern = "${data.confluent_schema_registry_cluster.essentials.resource_name}/subject=*"
}

resource "confluent_role_binding" "flink-app-sr-write" {
  principal   = "User:${confluent_service_account.flink-app.id}"
  role_name   = "DeveloperWrite"
  crn_pattern = "${data.confluent_schema_registry_cluster.essentials.resource_name}/subject=*"
}

# Flink developer - deploys Flink statements
resource "confluent_service_account" "flink-developer-sa" {
  display_name = "${var.prefix}-fd-sa"
  description  = "Service account to deploy Flink statements"
}

resource "confluent_role_binding" "flink-developer" {
  principal   = "User:${confluent_service_account.flink-developer-sa.id}"
  role_name   = "FlinkDeveloper"
  crn_pattern = confluent_environment.env.resource_name
}

resource "confluent_role_binding" "flink-assigner" {
  principal   = "User:${confluent_service_account.flink-developer-sa.id}"
  role_name   = "Assigner"
  crn_pattern = "${data.confluent_organization.my_org.resource_name}/service-account=${confluent_service_account.flink-app.id}"
}

# Flink API key for deploying statements
resource "confluent_api_key" "flink-api-key" {
  display_name = "${var.prefix}-flink-api-key"
  description  = "Flink API Key owned by flink-developer-sa"
  owner {
    id          = confluent_service_account.flink-developer-sa.id
    api_version = confluent_service_account.flink-developer-sa.api_version
    kind        = confluent_service_account.flink-developer-sa.kind
  }
  managed_resource {
    id          = data.confluent_flink_region.flink_region.id
    api_version = data.confluent_flink_region.flink_region.api_version
    kind        = data.confluent_flink_region.flink_region.kind
    environment {
      id = confluent_environment.env.id
    }
  }
}
```

Create `pools.tf` with Flink compute pools:

```terraform
# pools.tf - Flink compute pools

resource "confluent_flink_compute_pool" "default" {
  display_name = "default"
  cloud        = upper(data.confluent_flink_region.flink_region.cloud)
  region       = data.confluent_flink_region.flink_region.region
  max_cfu      = 50
  environment {
    id = confluent_environment.env.id
  }
}
```

### Step 4: Apply the Configuration

```sh
terraform init
terraform plan    # Verify imports and new resources
terraform apply
```

The plan should show:

- Existing resources being **imported** (environment, kafka cluster, service accounts)
- New Flink resources being **created** (flink-app, flink-developer-sa, role bindings, compute pool)


## Removing Flink resources

Compute pools with running Flink statements cannot be deleted - stop all statements first.

* If the compute pool is in your Terraform state, simply remove or comment out the resource block in the tf and output.tf and apply
  ```sh
  terraform plan
  terraform apply
  ```
  
* To destroy only a specific compute pool without removing it from config:
  ```sh
  terraform destroy -target=confluent_flink_compute_pool.data-generation
  ```

* If you want to stop managing it with Terraform but keep it running:
  ```sh
  terraform state rm confluent_flink_compute_pool.data-generation
  ```
