# -----------------------------------------------------------------------------
# Terraform and provider requirements
# Confluent Cloud API: CONFLUENT_CLOUD_API_KEY / CONFLUENT_CLOUD_API_SECRET.
# Flink: all 7 attributes below must be set together in the provider block.
# -----------------------------------------------------------------------------

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
  organization_id       = var.organization_id
  environment_id        = var.environment_id
  flink_compute_pool_id = var.flink_compute_pool_id
  flink_rest_endpoint   = var.rest_endpoint
  flink_api_key         = var.flink_api_key
  flink_api_secret      = var.flink_api_secret
  flink_principal_id    = var.principal_id
}
