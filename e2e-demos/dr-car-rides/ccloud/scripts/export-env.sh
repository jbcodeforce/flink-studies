#!/usr/bin/env bash
# Export Kafka / SR / Flink env for primary or dr from IaC outputs JSON.
# Usage: source export-env.sh primary|dr
set -euo pipefail

SITE="${1:-primary}"
_SRC="${BASH_SOURCE[0]:-$0}"
SCRIPT_DIR="$(cd "$(dirname "$_SRC")" && pwd)"
unset _SRC
OUTPUTS="${IAC_OUTPUTS:-$SCRIPT_DIR/iac-outputs.json}"

if [[ ! -f "$OUTPUTS" ]]; then
  echo "Missing $OUTPUTS — run: cd ../IaC && terraform output -json > ../scripts/iac-outputs.json" >&2
  return 1 2>/dev/null || exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required" >&2
  return 1 2>/dev/null || exit 1
fi

get() { jq -r ".$1.value // empty" "$OUTPUTS"; }

export KAFKA_TOPIC="${KAFKA_TOPIC:-rides_raw}"
export SEQ_LOG="${SEQ_LOG:-/tmp/dr-car-rides-seq.log}"
export CLUSTER_LINK_NAME
CLUSTER_LINK_NAME="$(get cluster_link_name)"
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

if [[ -z "${FLINK_API_KEY}" || -z "${FLINK_API_SECRET}" ]]; then
  echo "Missing Flink API key/secret in $OUTPUTS for site=$SITE" >&2
  return 1 2>/dev/null || exit 1
fi

echo "Exported env for site=$ACTIVE_SITE env=$CONFLUENT_ENVIRONMENT_ID pool=$FLINK_COMPUTE_POOL_ID db=$FLINK_DATABASE_NAME"
