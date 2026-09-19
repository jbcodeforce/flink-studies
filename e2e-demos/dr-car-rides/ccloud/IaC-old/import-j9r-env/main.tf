terraform {
  required_version = ">= 1.5.0"

  required_providers {
    confluent = {
      source  = "confluentinc/confluent"
      version = "2.86.0"
    }
  }
}

provider "confluent" {
  # Cloud API only — enough to import env / Kafka / SA.
  # Prefer CONFLUENT_CLOUD_API_KEY / CONFLUENT_CLOUD_API_SECRET env vars when these are empty.
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

# Resources imported via import.tf (j9r-env only).
resource "confluent_environment" "env" {
  display_name = "j9r-env"

  stream_governance {
    package = "ESSENTIALS"
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_kafka_cluster" "standard" {
  display_name        = "j9r-kafka"
  availability        = "SINGLE_ZONE"
  cloud               = "AWS"
  region              = "us-west-2"
  deletion_protection = false

  standard {
    max_ecku = 10
  }

  environment {
    id = confluent_environment.env.id
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_service_account" "env-manager" {
  display_name = "j9r-flink-app"
  description  = "Service account as which Flink statements run in the environment"

  lifecycle {
    prevent_destroy = true
  }
}
