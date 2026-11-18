# -----------------------------------------------------------------------------
# Layer 3 — Schema Linking: DR Schema Registry in IMPORT mode + exporter primary -> DR.
#
# Both Schema Registry endpoints are public, so this layer runs from the laptop:
#
#   scripts/generate-outputs.sh
#   scripts/tfvars-from-outputs.sh 03-schema-linking
#   terraform init && terraform apply
#
# IMPORT mode keeps schema ids identical on both sides, which is what lets a producer or
# consumer switch sites without re-resolving ids. Soft failover flips the DR registry back
# to READWRITE (scripts/failover-soft.sh) after pausing the exporter.
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

provider "confluent" {}
