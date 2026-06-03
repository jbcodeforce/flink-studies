#!/usr/bin/env bash
# Deploy perf-testing Flink SQL statements to Confluent Cloud (optional).
# Requires: confluent CLI logged in, FLINK_COMPUTE_POOL_ID or --compute-pool.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
POOL="${FLINK_COMPUTE_POOL_ID:-}"

if ! command -v confluent &>/dev/null; then
  echo "confluent CLI not found. Deploy SQL via Cloud Console instead."
  exit 1
fi

if [[ -z "$POOL" ]]; then
  echo "Set FLINK_COMPUTE_POOL_ID to your compute pool id (lfcp-...)"
  exit 1
fi

deploy_sql() {
  local name="$1"
  local file="$2"
  echo "Creating statement: $name"
  confluent flink statement create "$name" \
    --compute-pool "$POOL" \
    --sql-file "$file"
}

deploy_sql "perf-ddl-source" "$SCRIPT_DIR/ddl.perf_source.sql"
deploy_sql "perf-ddl-sink" "$SCRIPT_DIR/ddl.perf_sink.sql"
deploy_sql "perf-dml-passthrough" "$SCRIPT_DIR/dml.passthrough.sql"

echo "Statements submitted. Validate with validate.perf_output.sql in the UI or CLI."
