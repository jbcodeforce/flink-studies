#!/usr/bin/env bash
# Negative RBAC test: FlinkDeveloper must NOT be able to create Flink compute pools.
# FlinkAdmin (or higher) is required. See docs/techno/ccloud-flink.md role table.
#
# Authenticates with the same Flink-scoped API key as deploy_statement.sh
# (flink_api_key_id / flink_api_key_secret), owned by the FlinkDeveloper SA.
#
# Note: Confluent documents compute-pool management at api.confluent.cloud/fcpm/v2
# with a Cloud API key. A Flink-scoped key is the credential this SA uses for Flink SQL;
# the request should still fail (typically 401/403), proving the SA cannot provision pools.
#
# Prerequisites:
#   - terraform apply completed
#   - jq installed
#
# Usage:
#   ./create_compute_pool_denied.sh
#
# Exit 0 when the API rejects the request (expected).
# Exit 1 when a pool is created or the response is unexpected.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${MODULE_DIR}"

FLINK_API_KEY="$(terraform output -raw flink_api_key_id)"
FLINK_API_SECRET="$(terraform output -raw flink_api_key_secret)"
ENV_ID="$(terraform output -raw environment_id)"
PRINCIPAL_ID="$(terraform output -raw flink_developer_service_account_id)"
CLOUD_PROVIDER="$(terraform output -raw cloud_provider)"
CLOUD_REGION="$(terraform output -raw cloud_region)"

POOL_NAME="${POOL_NAME:-rbac-denied-pool-$(date +%s)}"
MAX_CFU="${MAX_CFU:-5}"

BASE64_AUTH="$(printf '%s:%s' "${FLINK_API_KEY}" "${FLINK_API_SECRET}" | base64 | tr -d '\n')"
COMPUTE_POOLS_URL="https://api.confluent.cloud/fcpm/v2/compute-pools"

PAYLOAD="$(jq -n \
  --arg display_name "${POOL_NAME}" \
  --arg cloud "${CLOUD_PROVIDER}" \
  --arg region "${CLOUD_REGION}" \
  --arg env_id "${ENV_ID}" \
  --argjson max_cfu "${MAX_CFU}" \
  '{
    spec: {
      display_name: $display_name,
      cloud: $cloud,
      region: $region,
      max_cfu: $max_cfu,
      environment: { id: $env_id }
    }
  }')"

echo "POST ${COMPUTE_POOLS_URL}"
echo "Auth: Flink-scoped API key (same as deploy_statement.sh)"
echo "Principal (FlinkDeveloper SA): ${PRINCIPAL_ID}"
echo "Pool name: ${POOL_NAME}"
echo "Cloud / region: ${CLOUD_PROVIDER} / ${CLOUD_REGION}"
echo "Expected: HTTP 401 or 403 — FlinkDeveloper / Flink API key cannot create compute pools"
echo

RESPONSE_FILE="$(mktemp)"
trap 'rm -f "${RESPONSE_FILE}"' EXIT

HTTP_CODE="$(
  curl --silent --show-error \
    --request POST \
    --url "${COMPUTE_POOLS_URL}" \
    --header "Authorization: Basic ${BASE64_AUTH}" \
    --header "Content-Type: application/json" \
    --output "${RESPONSE_FILE}" \
    --write-out '%{http_code}' \
    --data "${PAYLOAD}"
)"

echo "HTTP ${HTTP_CODE}"
jq . < "${RESPONSE_FILE}" 2>/dev/null || cat "${RESPONSE_FILE}"
echo

if [[ "${HTTP_CODE}" =~ ^2 ]]; then
  echo "UNEXPECTED: FlinkDeveloper created a compute pool (HTTP ${HTTP_CODE}). Check RBAC bindings." >&2
  exit 1
fi

echo "OK: request denied as expected (HTTP ${HTTP_CODE}). FlinkDeveloper cannot create compute pools."
exit 0
