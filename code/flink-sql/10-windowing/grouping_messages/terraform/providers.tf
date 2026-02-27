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
}
