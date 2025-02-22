# Using Terraform to deploy Flink App or Statement

Source of major information can be found in the [Terraform Confluent provider formal documentation,](https://developer.hashicorp.com/terraform/tutorials/applications/confluent-provider) and in the [examples of deployment](https://github.com/confluentinc/terraform-provider-confluent/tree/master/examples/configurations).

There are two approaches to manage Confluent Platform Kafka cluster in the same Terraform workspace:

1. Manage multiple clusters 
1. Manage a single Kafka cluster

But Terraform plugin also support Flink statement deployments on Confluent Cloud.

## Pre-requisites

* If not done create Confluent Cloud API key with secret for your user or for a service account (See [confluent.cloud/settings/api-keys](https://confluent.cloud/settings/api-keys)). Your user needs `OrganizationAdmin` role. For production do not use, user keys but prefer service account keys. 
* If not already done create a service account for terraform runner. Assign the OrganizationAdmin role to this service account by following [this guide](https://docs.confluent.io/cloud/current/access-management/access-control/cloud-rbac.html#add-a-role-binding-for-a-user-or-service-account).

* To get the visibility of the existing keys use the command:

    ```sh
    confluent api-key list | grep <cc_userid>>
    ```

* Export as environment variables:

    ```sh
    export CONFLUENT_CLOUD_API_KEY=
    export CONFLUENT_CLOUD_API_SECRET=
    ```

## Infrastructure

### Kafka

See the [Product documentation to create kafka cluster with Terraform](https://docs.confluent.io/cloud/current/clusters/terraform-provider.html). The [basic cluster sample project](https://registry.terraform.io/providers/confluentinc/confluent/latest/docs/guides/sample-project) describes the needed steps, but it is recommended to use standard kafka cluster with RBAC access control.

This repository includes a demo with IaC definition in the [deployment cc-terraform folder](https://github.com/jbcodeforce/flink-studies/tree/master/deployment/cc-terraform) which defines the following components:

* Confluent Cloud Environment
* A Service account to manage the environment: `env_manager` with the role of `EnvironmentAdmin` and API keys
* A Kafka cluster in a single AZ (for demo), with service accounts for app-manager, producer and consumer apps
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
* The output of this configuration needs to be used by other deployment like the Flink statement ones. It can be retrieved at any time with

    ```sh
    terraform output
    ```


## Deploy a Flink statement

Flink tatement can be deployed using Terraform: DDL is the easier part. Automation of DML statement is more complex: the first deployment on a fresh environment is simple, the challenges come when doing cannary deployment on existing running statements for logic upgrade. For that see [the statement life cycle chapter in the cookbook chapter.](../architecture/cookbook.md#statement-evolution)

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


