#!/usr/bin/env bash
# Usage: source scripts/unset_env_var.sh
# Must be sourced (not executed) to affect the current shell's environment.
#
# The confluent Terraform provider auto-reads KAFKA_*/FLINK_*/SCHEMA_REGISTRY_*
# and ENVIRONMENT_ID/ORGANIZATION_ID as provider-level credentials, and rejects
# a partial set ("attributes should be set or not set ... at the same time").
# After `source set_env_from_tf.sh` leaves those in the shell, source this before
# running terraform plan/apply.

# Guard: refuse to run as an executed subshell, where the unsets would be lost.
# bash and zsh report "sourced" differently, so detect per-shell. (The bash-only
# BASH_SOURCE test and the `(return)` idiom both fail to catch execution in zsh.)
_us_sourced=0
if [ -n "${ZSH_VERSION:-}" ]; then
  case "${ZSH_EVAL_CONTEXT:-}" in *:file*) _us_sourced=1 ;; esac
elif [ -n "${BASH_VERSION:-}" ]; then
  [ "${BASH_SOURCE[0]}" != "${0}" ] && _us_sourced=1
fi
if [ "$_us_sourced" -ne 1 ]; then
  echo "ERROR: This script must be sourced, not executed." >&2
  echo "  Run: source scripts/unset_env_var.sh" >&2
  exit 1
fi
unset _us_sourced

unset SCHEMA_REGISTRY_ID SCHEMA_REGISTRY_ENDPOINT SCHEMA_REGISTRY_REST_ENDPOINT SCHEMA_REGISTRY_URL
unset SCHEMA_REGISTRY_API_KEY SCHEMA_REGISTRY_API_SECRET SCHEMA_REGISTRY_KEY SCHEMA_REGISTRY_SECRET
unset ENVIRONMENT_ID ORGANIZATION_ID FLINK_ENV_ID
unset FLINK_API_KEY FLINK_API_SECRET FLINK_COMPUTE_POOL_ID FLINK_SNAPSHOT_COMPUTE_POOL_ID FLINK_REST_ENDPOINT FLINK_PRINCIPAL_ID
unset TF_VAR_schema_registry_id TF_VAR_schema_registry_rest_endpoint TF_VAR_schema_registry_api_key TF_VAR_schema_registry_api_secret
unset KAFKA_API_KEY KAFKA_API_SECRET KAFKA_REST_ENDPOINT KAFKA_ID 