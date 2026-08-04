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
  # Use CONFLUENT_CLOUD_API_KEY / CONFLUENT_CLOUD_API_SECRET from the environment.
  # Do not set schema_registry_* in this block (dual-env; per-resource credentials instead).
  # If plan fails with "All 4 schema_registry_* ...", your shell has partial SCHEMA_REGISTRY_*
  # env vars — unset them: unset SCHEMA_REGISTRY_ID SCHEMA_REGISTRY_REST_ENDPOINT SCHEMA_REGISTRY_API_KEY SCHEMA_REGISTRY_API_SECRET
}

# AWS providers are only needed when enable_tableflow=true.
# Iteration 1 uses placeholder credentials + skip flags so plan works without AWS.
locals {
  aws_skip = !var.enable_tableflow
}

provider "aws" {
  alias  = "primary"
  region = var.primary_region

  access_key                  = local.aws_skip ? "unused" : null
  secret_key                  = local.aws_skip ? "unused" : null
  skip_credentials_validation = local.aws_skip
  skip_requesting_account_id  = local.aws_skip
  skip_metadata_api_check     = local.aws_skip

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

  access_key                  = local.aws_skip ? "unused" : null
  secret_key                  = local.aws_skip ? "unused" : null
  skip_credentials_validation = local.aws_skip
  skip_requesting_account_id  = local.aws_skip
  skip_metadata_api_check     = local.aws_skip

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

  access_key                  = local.aws_skip ? "unused" : null
  secret_key                  = local.aws_skip ? "unused" : null
  skip_credentials_validation = local.aws_skip
  skip_requesting_account_id  = local.aws_skip
  skip_metadata_api_check     = local.aws_skip

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
