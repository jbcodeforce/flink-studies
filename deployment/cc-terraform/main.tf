# Terraform Provider Configuration for j9r-env
# Base infrastructure for Confluent Cloud Flink applications

terraform {
  required_providers {
    confluent = {
      source  = "confluentinc/confluent"
      version = "2.57.0"
    }
  }
}

provider "confluent" {
  cloud_api_key    = var.confluent_cloud_api_key
  cloud_api_secret = var.confluent_cloud_api_secret
}

# Data sources for organization and Flink region

data "confluent_organization" "my_org" {}

data "confluent_flink_region" "flink_region" {
  cloud  = var.cloud_provider
  region = var.cloud_region
}
