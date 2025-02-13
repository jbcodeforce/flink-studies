# My CCloud environment

The flink.tf in deployment cc-terraform: defines the following components: A flink pool, with 2 service accounts, one for flink app management and one for developing flink statements.

[See Terraform Confluent provider documentation.](https://registry.terraform.io/providers/confluentinc/confluent/latest/docs/guides/sample-project)

## Define basic variable in tfvars

Populate a tfvars with api key, secret, cloud provider and region.

## deployment

Use the classical tf commands:

```sh
terraform init
terraform plan
# use the AWS and us-west-2 region
terraform apply --auto-approve
```