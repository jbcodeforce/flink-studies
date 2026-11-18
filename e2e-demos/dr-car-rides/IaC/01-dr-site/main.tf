# -----------------------------------------------------------------------------
# Layer 1 — DR site (us-east-1): environment, Enterprise cluster, Flink pool,
# service account + keys, and the private network path (PrivateLink + bastion).
#
# Independent of Layer 0: nothing here reads primary state. Layers 2 and 3 read
# both L0 and L1 state.
#
# Prereqs:
#   export CONFLUENT_CLOUD_API_KEY=... CONFLUENT_CLOUD_API_SECRET=...
#   (only these two Confluent variables; unset SCHEMA_REGISTRY_* / FLINK_* / KAFKA_*)
#   aws sso login --profile <profile>   # then set aws_profile in terraform.tfvars
# -----------------------------------------------------------------------------

terraform {
  required_version = ">= 1.16"

  required_providers {
    confluent = {
      source  = "confluentinc/confluent"
      version = "~> 2.86"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "confluent" {
  # Credentials via CONFLUENT_CLOUD_API_KEY / CONFLUENT_CLOUD_API_SECRET env vars.
}

provider "aws" {
  region  = var.dr_region
  profile = var.aws_profile

  default_tags {
    tags = {
      Project = "dr-car-rides"
      Layer   = "01-dr-site"
    }
  }
}

data "confluent_organization" "org" {}

data "confluent_flink_region" "dr" {
  cloud  = "AWS"
  region = var.dr_region
}
