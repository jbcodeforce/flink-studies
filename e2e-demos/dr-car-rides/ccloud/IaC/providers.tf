# -----------------------------------------------------------------------------
# Terraform Providers — DR Car Rides Demo
# -----------------------------------------------------------------------------

terraform {
  required_version = ">= 1.3.0"

  required_providers {
    confluent = {
      source  = "confluentinc/confluent"
      version = "~> 2.58"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

provider "confluent" {
  cloud_api_key    = var.confluent_cloud_api_key
  cloud_api_secret = var.confluent_cloud_api_secret
}

provider "aws" {
  alias  = "primary"
  region = var.primary_region

  default_tags {
    tags = {
      Project     = "dr-car-rides"
      Environment = "demo"
      ManagedBy   = "terraform"
      Owner       = var.owner_email
      Role        = "primary"
    }
  }
}

provider "aws" {
  alias  = "dr"
  region = var.dr_region

  default_tags {
    tags = {
      Project     = "dr-car-rides"
      Environment = "demo"
      ManagedBy   = "terraform"
      Owner       = var.owner_email
      Role        = "dr"
    }
  }
}

# Default AWS provider for account identity / IAM (global)
provider "aws" {
  region = var.primary_region

  default_tags {
    tags = {
      Project     = "dr-car-rides"
      Environment = "demo"
      ManagedBy   = "terraform"
      Owner       = var.owner_email
    }
  }
}

resource "random_id" "suffix" {
  byte_length = 4
}
