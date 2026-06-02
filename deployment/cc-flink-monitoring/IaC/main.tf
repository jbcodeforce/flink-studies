terraform {
  required_providers {
    confluent = {
      source  = "confluentinc/confluent"
      version = "~> 2.57"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}

provider "confluent" {
  cloud_api_key    = var.confluent_cloud_api_key
  cloud_api_secret = var.confluent_cloud_api_secret
}

data "terraform_remote_state" "cc" {
  backend = "local"
  config = {
    path = abspath("${path.module}/../../cc-terraform/terraform.tfstate")
  }
}
