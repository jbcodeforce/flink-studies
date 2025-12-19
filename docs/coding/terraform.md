# Using Terraform to deploy Flink App or Statement

???- info "Version"
    * Created November 2024
    * Update December 2025 


* Get the last [Terraform cli version, from the installation guide.](https://developer.hashicorp.com/terraform/install).
    ```sh
    terraform version
    ```

???+ info "Core Principals"
    When you run `terraform apply`, Terraform calculates the differences between the current actual state (tracked in its state file) and the desired state, and then applies only the necessary changes to bridge that gap. This enables incremental building. 
    
    For confluent we can start with an environment, a service account, role binding and add resources over time. If we change a parameter of an existing resource (e.g., change an instance type), Terraform will detect this as a modification and update only that specific resource in place (if possible) or replace it if an in-place update isn't supported by the provider. Terraform automatically determines the correct order of operations based on resource dependencies, ensuring that foundational components are created before dependent components.
    
    For managing different stages like development, staging, and production, the recommended approach is to use separate configurations (often in different directories) with their own dedicated state files.

* [See Confluent Terraform sample project for an end-to-end tutorial](https://registry.terraform.io/providers/confluentinc/confluent/latest/docs/guides/sample-project). 
* The [Terraform Confluent provider formal documentation,](https://developer.hashicorp.com/terraform/tutorials/applications/confluent-provider) with the [deployment examples](https://github.com/confluentinc/terraform-provider-confluent/tree/master/examples/configurations).

There are two approaches to manage Confluent Platform Kafka cluster in the same Terraform workspace:

1. Manage multiple Kafka clusters 
1. Manage a single cluster

Terraform plugin supports Flink compute pool creation and Flink statement deployments on Confluent Cloud.

* This repository includes in [deployment/cc-terraform](https://github.com/jbcodeforce/flink-studies/tree/master/deployment/cc-terraform) Terraform definitions to create:
    * Confluent cloud environment
    * A Service Account as environement admin
    * Kafka Cluster with API key
    * A schema registry with API key
    * Flink service accounts: flink-app (with ClusterAdmin role, DeveloperRead and DeveloperWrite on schema registry), flink-developer-sa (FlinkDeveloper), Flink API key owned by Flink Developer SA
    * Flink compute pools: a default and one for data generations
    * Flink statements for clicks, customers, products data generation


    ```sh
    terraform validate
    ```

## Pre-requisites

* If not done already, create Confluent Cloud API key with secret for your user or for a service account (See [confluent.cloud/settings/api-keys](https://confluent.cloud/settings/api-keys)). Your user needs `OrganizationAdmin` role to create those keys. For production do not use, user keys but prefer service account keys. 
* If not already done create a service account for terraform runner. Assign the OrganizationAdmin role to this service account by following [this guide](https://docs.confluent.io/cloud/current/access-management/access-control/cloud-rbac.html#add-a-role-binding-for-a-user-or-service-account).

* To get the visibility of the existing keys use the command:
    ```sh
    confluent api-key list | grep <cc_userid>
    ```

* Export as environment variables:

    ```sh
    export CONFLUENT_CLOUD_API_KEY=
    export CONFLUENT_CLOUD_API_SECRET=
    ```

* Recall that terraform.tfstate and env variables should not be committed to git.

## Infrastructure

For any flink project, we need to define or import the following resources:

* Confluent cloud environment
* A Service Account as environement admin
* Kafka Cluster with API key
* A schema registry with API key
* Kafka Cluster
* Schema Registry
* Flink service accounts: flink-app (with ClusterAdmin role, DeveloperRead and DeveloperWrite on schema registry), flink-developer-sa (FlinkDeveloper), Flink API key owned by Flink Developer SA
* Flink compute pools: a default and one for data generations
* Flink statements for clicks, customers, products data generation

### Defining Terraform Provider and Variables

1. Create a main.tf with the confluent cloud provider. (see Confluent sample [here](https://github.com/confluentinc/terraform-provider-confluent/blob/master/examples/configurations/basic-kafka-acls/main.tf)), [or the main.tf in this repo](https://github.com/jbcodeforce/flink-studies/blob/master/deployment/cc-terraform/main.tf)

1. Init:
    ```sh
    terraform init
    ```
1. Add variables.tf: we need at least: `confluent_cloud_api_key, confluent_cloud_api_secret, cloud_provider, cloud_region and prefix`. Each variable definition has the same structure:
    ```terraform
    variable "prefix" {
        description = "Prefix for resource names to avoid conflicts"
        type        = string
        default     = "j9r"
    }
    ```

1. Define specific variable values using: terraform.tfvars or use default values.

### Iterative configuration

The approach is to add resources by increment to have a clear understanding of all dependencies. The iteration includes at least the following steps:

1. Add resources and variables
1. Decide to import existing resources or create new one
1. Run CLI:
    ```sh
    terraform validate
    terraform plan
    terraform apply
    ```

### Environment

* Define the [Confluent environment](https://registry.terraform.io/providers/confluentinc/confluent/latest/docs/resources/confluent_environment) in `env.tf`, and use a naming convention as: "${var.prefix}-env".
    ```tf
    resource "confluent_environment" "env" {
    display_name = "${var.prefix}-env"

    stream_governance {
        package = "ADVANCED"
    }
    }
    ```

* For an existing environment, use the import statement:
    ```
    import {
        to = confluent_environment.env
        id = "env-nknqp3"
    }
    ```

* Add service account and role binding as Environment admin 
    ```
    resource "confluent_service_account" "env-manager" {
        display_name = "${var.prefix}-env-manager"
        description  = "Service account to manage ${var.prefix}-env environment"
        depends_on = [
            confluent_environment.env
        ]
    }
    ```

    - or import existing service account id
    ```
    import {
        to = confluent_service_account.env-manager
        id = "sa-7vvrvw"
    }
    ```

### Kafka

See the [Product documentation to create kafka cluster with Terraform](https://docs.confluent.io/cloud/current/clusters/terraform-provider.html). The [basic cluster sample project](https://registry.terraform.io/providers/confluentinc/confluent/latest/docs/guides/sample-project) describes the needed steps, but it is recommended to use standard kafka cluster with RBAC access control. [As an alternate this is the standard cluster definitions](https://github.com/confluentinc/terraform-provider-confluent/tree/master/examples/configurations/standard-kafka-acls).

1. Create a [Kafka cluster](https://registry.terraform.io/providers/confluentinc/confluent/latest/docs/resources/confluent_kafka_cluster) resources:
    ```tf
    resource "confluent_kafka_cluster" "standard" {
        display_name = "${var.prefix}-kafka"
        availability = "SINGLE_ZONE"
        cloud        = var.cloud_provider
        region       = var.cloud_region
        standard {}

        environment {
            id = confluent_environment.env.id
        }
          lifecycle {
                prevent_destroy = true
            }
    }
    ```

    or import one exisitng 
    ```sh
    terraform import confluent_kafka_cluster.standard env-nknqp3/lkc-3mnm0m
    ```

This repository includes a demo with IaC definition in the [deployment cc-terraform folder](https://github.com/jbcodeforce/flink-studies/tree/master/deployment/cc-terraform) which defines the following components:

* A Service account to manage the environment: `env_manager` with the role of `EnvironmentAdmin` and API keys
* A Kafka cluster in a single AZ (for demo), with service accounts for app-manager, producer and consumer apps

### Schema Registry

* A schema registry with API keys to access the registry at runtime

### Compute pool

Flink Compute pool can also be configured with Terraform, and see this example in the [Terraform Confluent quickstart repository.](https://github.com/confluentinc/terraform-provider-confluent/tree/master/examples/configurations/flink-quickstart)

The `flink.tf` in [deployment cc-terraform:](https://github.com/jbcodeforce/flink-studies/tree/master/deployment/cc-terraform)  defines the following components:

* A flink pool, with 2 service accounts, one for flink app management and one for developing flink statements.

### Deploy the configuration

* Use the classical tf commands:

    ```sh
    terraform init
    terraform plan
    terraform apply --auto-approve
    ```

* If there is a 401 error on accessing Confluent, it is a problem of api_key within the environment variables.
* The output of this configuration needs to be used by other deployment like the Flink statement ones. It can be retrieved at any time with:
    ```sh
    terraform output
    ```


## Deploy a Flink statement

Flink statement can be deployed using Terraform: DDL is the easier part. Automation of DML statement is more complex: the first deployment on a fresh environment is simple, the challenges come when doing canary deployment on existing running statements for logic upgrade. For that see [the statement life cycle chapter in the cookbook chapter.](../architecture/cookbook.md#statement-evolution) and potentially when the number of statements are important and need to take into account running statement, it is recommended to consider adopting [shift_left util](https://jbcodeforce.github.io/shift_left_utils/)

[See the Terraform definition of the Flink Statement resource.](https://registry.terraform.io/providers/confluentinc/confluent/latest/docs/resources/confluent_flink_statement). One important constraint is that 
all 7 flink_api_key, flink_api_secret, flink_rest_endpoint, organization_id, environment_id, flink_compute_pool_id, flink_principal_id attributes should be set or not set in the provider block at the same time.

```json
resource "confluent_flink_statement" "ddl-dim_tenant-v1" {
properties = {
    "sql.current-catalog"  = var.current_catalog
    "sql.current-database" = var.current_database
}

statement  = file("${path.module}/sql-scripts/ddl.dim_tenant.sql")
statement_name = "dml-dim-tenant_v1"

stopped = false  # change when updating the statement
}
```

statement can be a reference to a file, or a string including the statement content.

```json
resource "confluent_flink_statement" "create-table" {
statement  = "CREATE TABLE ${local.table_name}(ts TIMESTAMP_LTZ(3), random_value INT);"
```


