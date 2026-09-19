# -----------------------------------------------------------------------------
# Terraform Providers — DR Car Rides Demo
# -----------------------------------------------------------------------------

terraform {
  required_version = ">= 1.16.3"

  required_providers {
    confluent = {
      source  = "confluentinc/confluent"
      version = "~> 2.86"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region_primary
}

provider "confluent" {
  # Use CONFLUENT_CLOUD_API_KEY / CONFLUENT_CLOUD_API_SECRET from the environment.
  # Do not set schema_registry_* in this block (dual-env; per-resource credentials instead).
  # If plan fails with "All 4 schema_registry_* ...", your shell has partial SCHEMA_REGISTRY_*
  # env vars — unset them: unset SCHEMA_REGISTRY_ID SCHEMA_REGISTRY_REST_ENDPOINT SCHEMA_REGISTRY_API_KEY SCHEMA_REGISTRY_API_SECRET
}

# ----------------------------------------
# Data read from existing environment
# ----------------------------------------

data "confluent_organization" "org_id" {}

data "confluent_environment" "primary_env" {
  id = "env-yk3jm6"
}

data "confluent_service_account" "primary_sa" {
  id = "sa-111z1z"
}

data "confluent_flink_region" "primary_region" {
  cloud  = "AWS"
  region = "us-west-2"
}

data "confluent_schema_registry_cluster" "primary_sr" {
   id = "lsrc-3oxyv2"
   environment {
    id = data.confluent_environment.primary_env.id
  }
  depends_on = [
    data.confluent_environment.primary_env
  ]
}

data "confluent_kafka_cluster" "primary_lkc" {
  id = "lkc-7v233w"
  environment {
    id = data.confluent_environment.primary_env.id
  }
  depends_on = [
    data.confluent_environment.primary_env
  ]
}