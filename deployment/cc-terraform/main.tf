# Terraform Provider Configuration for j9r-env
# Base infrastructure for Confluent Cloud Flink applications

terraform {
  required_providers {
    confluent = {
      source  = "confluentinc/confluent"
      version = "2.75.0"
    }
  }
}

provider "confluent" {
  cloud_api_key                 = var.confluent_cloud_api_key
  cloud_api_secret              = var.confluent_cloud_api_secret
  schema_registry_id            = var.schema_registry_id            # optionally use SCHEMA_REGISTRY_ID env var
  schema_registry_rest_endpoint = var.schema_registry_rest_endpoint # optionally use SCHEMA_REGISTRY_REST_ENDPOINT env var
  schema_registry_api_key       = var.schema_registry_api_key       # optionally use SCHEMA_REGISTRY_API_KEY env var
  schema_registry_api_secret    = var.schema_registry_api_secret  
  flink_api_key                 = var.flink_api_key
  flink_api_secret              = var.flink_api_secret
  flink_rest_endpoint           = var.flink_rest_endpoint
  organization_id               = var.organization_id
  environment_id                = var.environment_id
  flink_compute_pool_id         = var.flink_compute_pool_id
  flink_principal_id            = var.flink_principal_id
}

# Data sources for organization and Flink region

data "confluent_organization" "my_org" {}

data "confluent_flink_region" "flink_region" {
  cloud  = var.cloud_provider
  region = var.cloud_region
}
