# -----------------------------------------------------------------------------
# Terraform Providers Configuration
# Card Transaction Processing Demo
# -----------------------------------------------------------------------------

terraform {
  required_version = ">= 1.3.0"

  required_providers {
    confluent = {
      source  = "confluentinc/confluent"
      version = "~> 2.5"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
  }
}

# -----------------------------------------------------------------------------
# AWS Provider
# -----------------------------------------------------------------------------
provider "aws" {
  region = var.cloud_region

  default_tags {
    tags = {
      Project     = "card-tx-demo"
      Environment = "demo"
      ManagedBy   = "terraform"
      Owner       = var.owner_email
    }
  }
}

# -----------------------------------------------------------------------------
# Confluent Cloud Provider
# -----------------------------------------------------------------------------
provider "confluent" {
  cloud_api_key    = var.confluent_cloud_api_key
  cloud_api_secret = var.confluent_cloud_api_secret
}

# -----------------------------------------------------------------------------
# Random ID for unique resource naming
# -----------------------------------------------------------------------------
resource "random_id" "env_display_id" {
  byte_length = 4
}
