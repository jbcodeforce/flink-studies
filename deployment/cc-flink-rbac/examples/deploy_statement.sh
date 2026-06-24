#!/usr/bin/env bash
# Deploy a Flink SQL statement via the Confluent Flink REST API.
# Authenticates with the Flink-scoped API key created by this Terraform module.
#
# Prerequisites:
#   - terraform apply completed in deployment/cc-flink-rbac
#   - jq installed
#
# Usage:
#   ./deploy_statement.sh
#   SQL_FILE=../other.sql STATEMENT_NAME=my-demo ./deploy_statement.sh
#   SQL='SELECT 1;' STATEMENT_NAME=select-1 ./deploy_statement.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${MODULE_DIR}"

FLINK_API_KEY="$(terraform output -raw flink_api_key_id)"
FLINK_API_SECRET="$(terraform output -raw flink_api_key_secret)"
ORG_ID="$(terraform output -raw organization_id)"
ENV_ID="$(terraform output -raw environment_id)"
COMPUTE_POOL_ID="$(terraform output -raw flink_compute_pool_id)"
FLINK_BASE="$(terraform output -raw flink_rest_endpoint)"
PRINCIPAL_ID="$(terraform output -raw flink_developer_service_account_id)"
CATALOG="$(terraform output -raw sql_current_catalog)"
DATABASE="$(terraform output -raw sql_current_database)"

STATEMENT_NAME="${STATEMENT_NAME:-rbac-gcp-demo}"
SQL_FILE="${SQL_FILE:-${SCRIPT_DIR}/ddl.gcp_demo.sql}"
STOPPED="${STOPPED:-false}"

if [[ -n "${SQL:-}" ]]; then
  STATEMENT_SQL="${SQL}"
elif [[ -f "${SQL_FILE}" ]]; then
  STATEMENT_SQL="$(tr -d '\r' < "${SQL_FILE}")"
else
  echo "No SQL provided and file not found: ${SQL_FILE}" >&2
  exit 1
fi

BASE64_AUTH="$(printf '%s:%s' "${FLINK_API_KEY}" "${FLINK_API_SECRET}" | base64 | tr -d '\n')"
STATEMENTS_URL="${FLINK_BASE}/sql/v1/organizations/${ORG_ID}/environments/${ENV_ID}/statements"

PAYLOAD="$(jq -n \
  --arg name "${STATEMENT_NAME}" \
  --arg org_id "${ORG_ID}" \
  --arg env_id "${ENV_ID}" \
  --arg statement "${STATEMENT_SQL}" \
  --arg catalog "${CATALOG}" \
  --arg database "${DATABASE}" \
  --arg compute_pool_id "${COMPUTE_POOL_ID}" \
  --arg principal "${PRINCIPAL_ID}" \
  --argjson stopped "${STOPPED}" \
  '{
    name: $name,
    organization_id: $org_id,
    environment_id: $env_id,
    spec: {
      statement: $statement,
      properties: {
        "sql.current-catalog": $catalog,
        "sql.current-database": $database
      },
      compute_pool_id: $compute_pool_id,
      principal: $principal,
      stopped: $stopped
    }
  }')"

echo "POST ${STATEMENTS_URL}"
echo "Statement name: ${STATEMENT_NAME}"
echo "Catalog: ${CATALOG}"
echo "Database: ${DATABASE}"
echo "Principal: ${PRINCIPAL_ID}"
echo "Compute pool: ${COMPUTE_POOL_ID}"
if [[ -z "${SQL:-}" ]]; then
  echo "SQL file: ${SQL_FILE}"
fi

curl --fail-with-body --silent --show-error \
  --request POST \
  --url "${STATEMENTS_URL}" \
  --header "Authorization: Basic ${BASE64_AUTH}" \
  --header "Content-Type: application/json" \
  --data "${PAYLOAD}" \
  | jq .
