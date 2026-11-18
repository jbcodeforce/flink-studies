# -----------------------------------------------------------------------------
# Layer 2 — Cluster Link primary -> DR + mirror topics on DR.
#
# RUNS ON THE DR BASTION, NOT ON THE LAPTOP: the DR cluster is private (PrivateLink), so its
# REST endpoint only resolves inside the VPC (from the laptop: "lookup lkc-...: no such host").
# From the laptop, run:
#
#   AWS_PROFILE=<profile> scripts/apply-cluster-link.sh [--plan | --destroy]
#
# Inputs come from variables, not remote state, because the bastion does not hold the
# Layer 0/1 state files. On the bastion that script does:
#
#   scripts/pull-outputs.sh                       # fetch iac-outputs.json
#   scripts/tfvars-from-outputs.sh 02-cluster-link
#   terraform init && terraform apply             # in IaC/02-cluster-link
#
# The state of this layer lives on the bastion (/opt/dr-car-rides/IaC/02-cluster-link).
#
# No Confluent Cloud API key is needed: every call uses a Kafka API key of the DR/primary
# clusters. Layer 2 creates NO topics on the primary: rides_raw is owned by Layer 0, and it is
# the only mirrored topic. rides_clean / driver_stats are derived: dbt re-creates them on DR at
# failover (earliest-offset on the mirrored rides_raw), so they are neither mirrored nor exported.
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
