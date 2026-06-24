terraform {
  required_providers {
    confluent = {
      source  = "confluentinc/confluent"
      version = "~> 2.75"
    }
  }
}

provider "confluent" {
  # CONFLUENT_CLOUD_API_KEY and CONFLUENT_CLOUD_API_SECRET from the environment.
  # Explicit empty SR fields override partial SCHEMA_REGISTRY_* env vars (provider requires all 4 or none).
  schema_registry_id            = var.schema_registry_id
  schema_registry_rest_endpoint = var.schema_registry_rest_endpoint
  schema_registry_api_key       = var.schema_registry_api_key
  schema_registry_api_secret    = var.schema_registry_api_secret
  flink_api_key                 = var.flink_api_key
  flink_api_secret              = var.flink_api_secret
  flink_rest_endpoint           = var.flink_rest_endpoint
  organization_id               = var.organization_id
  environment_id                = var.environment_id
  flink_compute_pool_id         = var.flink_compute_pool_id
  flink_principal_id            = var.flink_principal_id
}

data "terraform_remote_state" "cc" {
  count   = var.use_remote_state ? 1 : 0
  backend = "local"
  config = {
    path = abspath(var.cc_terraform_state_path)
  }
}

data "confluent_organization" "org" {}

data "confluent_flink_region" "flink_region" {
  cloud  = var.cloud_provider
  region = var.cloud_region
}
