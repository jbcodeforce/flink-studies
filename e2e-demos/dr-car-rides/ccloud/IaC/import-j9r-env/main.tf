terraform {
  required_version = ">= 1.5.0"

  required_providers {
    confluent = {
      source  = "confluentinc/confluent"
      version = "2.81.0"
    }
  }
}

provider "confluent" {
  # Cloud API only — enough to import env / Kafka / SA.
  # Prefer CONFLUENT_CLOUD_API_KEY / CONFLUENT_CLOUD_API_SECRET env vars when these are empty.
  cloud_api_key    = var.confluent_cloud_api_key != "" ? var.confluent_cloud_api_key : null
  cloud_api_secret = var.confluent_cloud_api_secret != "" ? var.confluent_cloud_api_secret : null
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
