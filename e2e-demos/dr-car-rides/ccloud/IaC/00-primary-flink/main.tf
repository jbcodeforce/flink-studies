# -----------------------------------------------------------------------------
# Layer 0 — Primary Flink + DR-Demo Producer Resources
# Adds a dedicated Flink compute pool and producer SA/keys for the DR demo
# on the EXISTING j9r-env / j9r-kafka primary.
#
# No changes are made to deployment/cc-terraform (which owns j9r-env itself).
#
# Prereqs:
#   export CONFLUENT_CLOUD_API_KEY=...
#   export CONFLUENT_CLOUD_API_SECRET=...
#   # Unset any SCHEMA_REGISTRY_* env vars before running:
#   unset SCHEMA_REGISTRY_ID SCHEMA_REGISTRY_REST_ENDPOINT \
#         SCHEMA_REGISTRY_API_KEY SCHEMA_REGISTRY_API_SECRET
# -----------------------------------------------------------------------------

terraform {
  required_version = ">= 1.16"

  required_providers {
    confluent = {
      source  = "confluentinc/confluent"
      version = "~> 2.86"
    }
  }
}

provider "confluent" {
  # Credentials via CONFLUENT_CLOUD_API_KEY / CONFLUENT_CLOUD_API_SECRET env vars.
  # Do NOT set schema_registry_* or flink_* here — managed per-resource.
}

# -----------------------------------------------------------------------------
# Read existing primary resources (j9r-env / j9r-kafka / j9r-sr)
# These IDs are stable and owned by deployment/cc-terraform.
# -----------------------------------------------------------------------------

data "confluent_organization" "org" {}

data "confluent_environment" "primary" {
  id = var.primary_environment_id
}

data "confluent_kafka_cluster" "primary" {
  id = var.primary_kafka_cluster_id
  environment {
    id = data.confluent_environment.primary.id
  }
}

data "confluent_schema_registry_cluster" "primary" {
  id = var.primary_schema_registry_id
  environment {
    id = data.confluent_environment.primary.id
  }
}

data "confluent_flink_region" "primary" {
  cloud  = "AWS"
  region = var.primary_region
}
