#!/usr/bin/env bash
# Export Kafka / SR / Flink env for primary or dr from IaC outputs JSON.
# Usage: source export-env.sh primary|dr
#
# This file is SOURCED, often into an interactive shell. It must not change shell options:
# `set -e` here would stay on after sourcing, and the next failing command (for example a
# failed scripts/bastion-sync.sh) would close the terminal. Scripts that source it set their
# own strict mode; failures are reported by the explicit checks below.

SITE="${1:-primary}"
_SRC="${BASH_SOURCE[0]:-$0}"
SCRIPT_DIR="$(cd "$(dirname "$_SRC")" && pwd)"
unset _SRC
OUTPUTS="${IAC_OUTPUTS:-$SCRIPT_DIR/iac-outputs.json}"

if [[ ! -f "$OUTPUTS" ]]; then
  echo "Missing $OUTPUTS — run: scripts/generate-outputs.sh (or: terraform output -json per IaC layer)" >&2
  return 1 2>/dev/null || exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required" >&2
  return 1 2>/dev/null || exit 1
fi

get() { jq -r ".$1.value // empty" "$OUTPUTS"; }

export KAFKA_TOPIC="${KAFKA_TOPIC:-rides_raw}"
export ORGANIZATION_ID
ORGANIZATION_ID="$(get organization_id)"
export SEQ_LOG="${SEQ_LOG:-/tmp/dr-car-rides-seq.log}"
export CLUSTER_LINK_NAME
# Layer 2 state lives on the bastion, so the laptop's merged outputs may not contain it.
CLUSTER_LINK_NAME="$(get cluster_link_name)"
CLUSTER_LINK_NAME="${CLUSTER_LINK_NAME:-dr-rides-primary-to-dr}"
export SCHEMA_EXPORTER_NAME
SCHEMA_EXPORTER_NAME="$(get schema_exporter_name)"

if [[ "$SITE" == "primary" ]]; then
  export CONFLUENT_ENVIRONMENT_ID
  CONFLUENT_ENVIRONMENT_ID="$(get primary_environment_id)"
  export SCHEMA_REGISTRY_ENDPOINT
  SCHEMA_REGISTRY_ENDPOINT="$(get primary_schema_registry_rest_endpoint)"
  export SCHEMA_REGISTRY_API_KEY
  SCHEMA_REGISTRY_API_KEY="$(get producer_sr_primary_api_key)"
  export SCHEMA_REGISTRY_API_SECRET
  SCHEMA_REGISTRY_API_SECRET="$(get producer_sr_primary_api_secret)"
  export KAFKA_BOOTSTRAP_SERVERS
  KAFKA_BOOTSTRAP_SERVERS="$(get primary_bootstrap_endpoint)"
  export KAFKA_API_KEY
  KAFKA_API_KEY="$(get producer_primary_api_key)"
  export KAFKA_API_SECRET
  KAFKA_API_SECRET="$(get producer_primary_api_secret)"
  export KAFKA_REST_ENDPOINT
  KAFKA_REST_ENDPOINT="$(get primary_rest_endpoint)"
  export KAFKA_CLUSTER_ID
  KAFKA_CLUSTER_ID="$(get primary_kafka_cluster_id)"
  export FLINK_API_KEY
  FLINK_API_KEY="$(get flink_api_key_primary)"
  export FLINK_API_SECRET
  FLINK_API_SECRET="$(get flink_api_secret_primary)"
  export FLINK_COMPUTE_POOL_ID
  FLINK_COMPUTE_POOL_ID="$(get primary_flink_compute_pool_id)"
  export FLINK_REST_ENDPOINT
  FLINK_REST_ENDPOINT="$(get primary_flink_rest_endpoint)"
  export FLINK_DATABASE_NAME
  FLINK_DATABASE_NAME="$(get primary_kafka_cluster_display_name)"
  export CLOUD_REGION
  CLOUD_REGION="$(get primary_region)"
  export FLINK_ENDPOINT=""   # primary uses the public Flink API (cloud + region)
  export ACTIVE_SITE=primary
elif [[ "$SITE" == "dr" ]]; then
  export CONFLUENT_ENVIRONMENT_ID
  CONFLUENT_ENVIRONMENT_ID="$(get dr_environment_id)"
  export SCHEMA_REGISTRY_ENDPOINT
  SCHEMA_REGISTRY_ENDPOINT="$(get dr_schema_registry_rest_endpoint)"
  export SCHEMA_REGISTRY_API_KEY
  SCHEMA_REGISTRY_API_KEY="$(get producer_sr_dr_api_key)"
  export SCHEMA_REGISTRY_API_SECRET
  SCHEMA_REGISTRY_API_SECRET="$(get producer_sr_dr_api_secret)"
  export KAFKA_BOOTSTRAP_SERVERS
  KAFKA_BOOTSTRAP_SERVERS="$(get dr_bootstrap_endpoint)"
  export KAFKA_API_KEY
  KAFKA_API_KEY="$(get producer_dr_api_key)"
  export KAFKA_API_SECRET
  KAFKA_API_SECRET="$(get producer_dr_api_secret)"
  export KAFKA_REST_ENDPOINT
  KAFKA_REST_ENDPOINT="$(get dr_rest_endpoint)"
  export KAFKA_CLUSTER_ID
  KAFKA_CLUSTER_ID="$(get dr_kafka_cluster_id)"
  export FLINK_API_KEY
  FLINK_API_KEY="$(get flink_api_key_dr)"
  export FLINK_API_SECRET
  FLINK_API_SECRET="$(get flink_api_secret_dr)"
  export FLINK_COMPUTE_POOL_ID
  FLINK_COMPUTE_POOL_ID="$(get dr_flink_compute_pool_id)"
  export FLINK_REST_ENDPOINT
  FLINK_REST_ENDPOINT="$(get dr_flink_rest_endpoint)"
  export FLINK_DATABASE_NAME
  FLINK_DATABASE_NAME="$(get dr_kafka_cluster_display_name)"
  export CLOUD_REGION
  CLOUD_REGION="$(get dr_region)"
  # DR is private (PrivateLink): Flink statements must use the private Flink endpoint, which
  # is flink.<PLATT dns domain>. An explicit dr_flink_private_endpoint output wins. The name
  # only resolves inside the DR VPC, so dbt for DR runs on the bastion.
  export FLINK_ENDPOINT
  FLINK_ENDPOINT="$(get dr_flink_private_endpoint)"
  if [[ -z "$FLINK_ENDPOINT" ]]; then
    _platt_domain="$(get dr_platt_dns_domain)"
    [[ -z "$_platt_domain" ]] || FLINK_ENDPOINT="https://flink.${_platt_domain}"
    unset _platt_domain
  fi
  export ACTIVE_SITE=dr
else
  echo "Usage: source export-env.sh primary|dr" >&2
  return 1 2>/dev/null || exit 1
fi

# Aliases expected by cc_deploy.get_config
export FLINK_ENV_ID="${CONFLUENT_ENVIRONMENT_ID}"
export ENVIRONMENT_ID="${CONFLUENT_ENVIRONMENT_ID}"
export ENV_ID="${CONFLUENT_ENVIRONMENT_ID}"
export CLOUD_PROVIDER="${CLOUD_PROVIDER:-aws}"
# dbt profile j9r: Flink catalog = FLINK_ENV_ID, Flink database (schema) = KAFKA_CLUSTER_NAME
export KAFKA_CLUSTER_NAME="${FLINK_DATABASE_NAME}"

if [[ -z "${FLINK_API_KEY}" || -z "${FLINK_API_SECRET}" ]]; then
  echo "Missing Flink API key/secret in $OUTPUTS for site=$SITE" >&2
  return 1 2>/dev/null || exit 1
fi

echo "Exported env for site=$ACTIVE_SITE env=$CONFLUENT_ENVIRONMENT_ID pool=$FLINK_COMPUTE_POOL_ID db=$FLINK_DATABASE_NAME"
