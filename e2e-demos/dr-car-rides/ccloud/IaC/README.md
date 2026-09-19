# Disaster Recovery Site

Primary site is defined in deployment/cc-terraform. This readme address a phase approach to define disaster recovery resources in a dedicated environment

## Resousces for the following configuration

* [Terraform Confluent](https://registry.terraform.io/providers/confluentinc/confluent/latest/docs)
* [WS PrivateLink for Serverless Products on Confluent Cloud](https://docs.confluent.io/cloud/current/networking/aws-platt.html)

## Phase 1: Disaster Environment, Kafa

### 1. Read Primary Environment

* Define the data from primary environment in the `main.tf` and `outputs.tf`

```bash
export CONFLUENT_CLOUD_API_KEY=...
export CONFLUENT_CLOUD_API_SECRET=...
terraform init
terraform plan
```

### 2. Create second env, kafka, schema registry

* Add environment in `dr_site.rf` with matching ouputs.
* Add Confluent gateway to private network
* Add Kafka, to get cluster link, we need enterprise cluster. Enterprise clusters are private by default and require confluent_private_link_attachment plus confluent_private_link_attachment_connection

* Add schema registry

