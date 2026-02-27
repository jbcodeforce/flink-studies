# Confluent Cloud and Flink settings for Terraform.
# Sources ~/.confluent/.env via load_confluent_env.sh, then exports TF_VAR_* and
# provider vars. Use the same key names in .env as below (or set TF_VAR_* directly in .env).
#
# Usage (from terraform/):
#   source load_confluent_env.sh
#   source env.confluent.sh
#   terraform plan && terraform apply
#
# Terraform reads TF_VAR_<name> automatically. The Confluent provider uses
# CONFLUENT_CLOUD_API_KEY and CONFLUENT_CLOUD_API_SECRET when set.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-.}")" && pwd)"
# Load ~/.confluent/.env into this shell (exports all KEY=value from that file)
# shellcheck source=load_confluent_env.sh
[ -f "$SCRIPT_DIR/load_confluent_env.sh" ] && . "$SCRIPT_DIR/load_confluent_env.sh"

# Map common .env keys to TF_VAR_* (use value from .env if set, else keep existing)
export TF_VAR_organization_id="${ORGANIZATION_ID:-${TF_VAR_organization_id:-}}"
export TF_VAR_environment_id="${ENVIRONMENT_ID:-${TF_VAR_environment_id:-}}"
export TF_VAR_kafka_cluster_id="${KAFKA_CLUSTER_ID:-${TF_VAR_kafka_cluster_id:-}}"
export TF_VAR_flink_compute_pool_id="${FLINK_COMPUTE_POOL_ID:-${TF_VAR_flink_compute_pool_id:-}}"
export TF_VAR_principal_id="${PRINCIPAL_ID:-${TF_VAR_principal_id:-}}"
export TF_VAR_flink_api_key="${FLINK_API_KEY:-${TF_VAR_flink_api_key:-}}"
export TF_VAR_flink_api_secret="${FLINK_API_SECRET:-${TF_VAR_flink_api_secret:-}}"
export TF_VAR_flink_rest_endpoint="${FLINK_REST_ENDPOINT:-${TF_VAR_flink_rest_endpoint:-}}"
# Provider auth (use CONFLUENT_CLOUD_API_KEY/SECRET from .env if set)
export CONFLUENT_CLOUD_API_KEY="${CONFLUENT_CLOUD_API_KEY:-}"
export CONFLUENT_CLOUD_API_SECRET="${CONFLUENT_CLOUD_API_SECRET:-}"
