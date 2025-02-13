terraform {
  required_providers {
    confluent = {
      source  = "confluentinc/confluent"
      version = "2.16.0"
    }
  }
}

provider "confluent" {
  endpoint = "https://confluent.cloud/api"
}

data "confluent_flink_region" "flink_region" {
  cloud  = var.cloud_provider
  region = var.cloud_region
  
}

data "confluent_organization" "my_org" {}









