#!/usr/bin/env bash
# Layer 2 (IaC/02-cluster-link) from the LAPTOP: the Terraform itself runs ON THE DR BASTION.
#
# Why: the cluster link and the mirror topics are created through the DR Kafka REST endpoint,
# which is private (PrivateLink) and only resolves inside the DR VPC. From the laptop,
# `terraform apply` fails with "lookup lkc-....private.confluent.cloud: no such host".
#
# What it does, on the bastion (through SSM, via bastion-sync.sh):
#   scripts/pull-outputs.sh                       fetch iac-outputs.json (secrets via Parameter Store)
#   scripts/tfvars-from-outputs.sh 02-cluster-link
#   terraform init && terraform apply|plan|destroy in IaC/02-cluster-link
# The Layer 2 state stays ON THE BASTION (/opt/dr-car-rides/IaC/02-cluster-link): the sync archive
# never carries state files, so a later sync does not overwrite it.
#
# Prerequisites: scripts/push-outputs.sh was run after the last layer apply, and
# scripts/bastion-setup.sh was run once (terraform, uv, git on the bastion).
#
# Usage:
#   AWS_PROFILE=<profile> scripts/apply-cluster-link.sh [--plan | --destroy] [--yes]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ACTION="apply"
ASSUME_YES=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --plan) ACTION="plan"; shift ;;
    --destroy) ACTION="destroy"; shift ;;
    --yes) ASSUME_YES=1; shift ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done

if [[ "$ACTION" != "plan" && "$ASSUME_YES" -ne 1 ]]; then
  read -r -p "Run 'terraform $ACTION' for Layer 2 (cluster link + rides_raw mirror) on the bastion? [y/N] " answer
  [[ "$answer" == "y" || "$answer" == "Y" ]] || { echo "Aborted."; exit 1; }
fi

case "$ACTION" in
  plan) tf="terraform plan -input=false -no-color" ;;
  apply) tf="terraform apply -auto-approve -input=false -no-color" ;;
  destroy) tf="terraform destroy -auto-approve -input=false -no-color" ;;
esac

"$SCRIPT_DIR/bastion-sync.sh" -- "scripts/pull-outputs.sh && scripts/tfvars-from-outputs.sh 02-cluster-link && cd IaC/02-cluster-link && terraform init -input=false -no-color >/dev/null && $tf"
