terraform {
  required_version = ">= 1.3.0"

  required_providers {
    confluent = {
      source  = "confluentinc/confluent"
      version = "~> 2.58"
    }
  }
}

provider "confluent" {
  cloud_api_key    = var.confluent_cloud_api_key != "" ? var.confluent_cloud_api_key : null
  cloud_api_secret = var.confluent_cloud_api_secret != "" ? var.confluent_cloud_api_secret : null

  organization_id       = var.organization_id
  environment_id        = var.environment_id
  flink_compute_pool_id = var.flink_compute_pool_id
  flink_principal_id   = var.principal_id
  flink_api_key        = var.flink_api_key
  flink_api_secret     = var.flink_api_secret
  flink_rest_endpoint  = var.flink_rest_endpoint
}
