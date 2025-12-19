# My CCloud environment

[See the terraform chapter](http://jbcodeforce.git.io/flink-studies/coding/terraform/)

## Define basic variable in tfvars

Populate a tfvars with prefix, cloud provider and region.
Set environment variables for 
```sh
export  TF_VAR_confluent_cloud_api_key=""
export  TF_VAR_confluent_cloud_api_secret=""
```

## deployment

Use the classical tf commands:

```sh
terraform init
terraform plan
# use the AWS and us-west-2 region
terraform apply --auto-approve
```