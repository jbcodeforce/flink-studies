#!/usr/bin/env bash
# Write IaC/<layer>/terraform.tfvars.json (mode 600, gitignored) from scripts/iac-outputs.json.
# Layers 2 and 3 take plain variables instead of terraform_remote_state, so they run wherever
# iac-outputs.json is available. Layer 2 MUST run on the DR bastion (private DR Kafka REST
# endpoint; this script refuses to write its tfvars elsewhere). Layer 3 runs on the laptop.
#
# Usage: scripts/tfvars-from-outputs.sh 02-cluster-link | 03-schema-linking
set -euo pipefail

LAYER="${1:?usage: tfvars-from-outputs.sh 02-cluster-link|03-schema-linking}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUTS="${IAC_OUTPUTS:-$SCRIPT_DIR/iac-outputs.json}"
TARGET="$SCRIPT_DIR/../IaC/$LAYER/terraform.tfvars.json"

[[ -f "$OUTPUTS" ]] || { echo "Missing $OUTPUTS - run generate-outputs.sh or pull-outputs.sh" >&2; exit 1; }
command -v jq >/dev/null || { echo "jq is required" >&2; exit 1; }

case "$LAYER" in
  02-cluster-link)
    # Layer 2 talks to the private DR Kafka REST endpoint: refuse to prepare it outside the DR VPC.
    "$SCRIPT_DIR/require-private-dns.sh" "$(jq -r '.dr_rest_endpoint.value' "$OUTPUTS")" \
      || { echo "Layer 2 must run on the bastion: use scripts/apply-cluster-link.sh" >&2; exit 1; }
    FILTER='{
      primary_kafka_cluster_id:   .primary_kafka_cluster_id.value,
      primary_bootstrap_endpoint: .primary_bootstrap_endpoint.value,
      primary_kafka_api_key:      .producer_primary_api_key.value,
      primary_kafka_api_secret:   .producer_primary_api_secret.value,
      dr_kafka_cluster_id:        .dr_kafka_cluster_id.value,
      dr_rest_endpoint:           .dr_rest_endpoint.value,
      dr_kafka_api_key:           .producer_dr_api_key.value,
      dr_kafka_api_secret:        .producer_dr_api_secret.value
    }' ;;
  03-schema-linking)
    FILTER='{
      primary_schema_registry_id:            .primary_schema_registry_id.value,
      primary_schema_registry_rest_endpoint: .primary_schema_registry_rest_endpoint.value,
      primary_sr_api_key:                    .producer_sr_primary_api_key.value,
      primary_sr_api_secret:                 .producer_sr_primary_api_secret.value,
      dr_schema_registry_id:                 .dr_schema_registry_id.value,
      dr_schema_registry_rest_endpoint:      .dr_schema_registry_rest_endpoint.value,
      dr_sr_api_key:                         .producer_sr_dr_api_key.value,
      dr_sr_api_secret:                      .producer_sr_dr_api_secret.value
    }' ;;
  *) echo "Unknown layer $LAYER" >&2; exit 1 ;;
esac

umask 077
jq "$FILTER" "$OUTPUTS" >"$TARGET"
# Fail loudly if any value is missing (null) instead of letting terraform prompt.
if jq -e 'to_entries | map(select(.value == null)) | length > 0' "$TARGET" >/dev/null; then
  echo "Some values are missing in $OUTPUTS:" >&2
  jq -r 'to_entries[] | select(.value == null) | .key' "$TARGET" >&2
  rm -f "$TARGET"
  exit 1
fi
echo "Wrote $TARGET" >&2
