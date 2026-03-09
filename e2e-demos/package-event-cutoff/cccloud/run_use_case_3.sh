#!/usr/bin/env bash
# Deploy use case 3: compute ETA from package_events (with location fields) via package_eta_history and join.
# Assumes package_events already exists with extended schema (run use case 1 first). Order: DDL (package_eta_history), DML (package_eta_history), DML (compute_eta).

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Reuse shared functions (statement_exists, get_table_list, table_exists, create_table)
# shellcheck source=package_event_cutoff_lib.sh
source "${SCRIPT_DIR}/package_event_cutoff_lib.sh"

# Context: 3rd line, 2nd column of 'confluent context list' (Name column)
if [ -z "${FLINK_CONTEXT}" ]; then
  FLINK_CONTEXT=$(confluent context list 2>/dev/null | sed -n '3p' | awk -F'|' '{print $2}' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
fi
if [ -z "${FLINK_CONTEXT}" ]; then
  echo "Error: FLINK_CONTEXT is empty. Set it or run 'confluent context list' (context is 3rd line, 2nd column)." >&2
  exit 1
fi

# Set Flink endpoint explicitly to avoid "No Flink endpoint is specified, defaulting to public endpoint..."
FLINK_ENDPOINT="${FLINK_ENDPOINT:-https://flink.us-west-2.aws.confluent.cloud}"

confluent flink region use --cloud ${CLOUD} --region ${REGION}
confluent flink endpoint use "${FLINK_ENDPOINT}"

TABLE_LIST=$(get_table_list)
STATEMENT_LIST=$(confluent flink statement list -o json --cloud "${CLOUD}" --region "${REGION}" --compute-pool "${FLINK_COMPUTE_POOL}" --environment "${FLINK_ENVIRONMENT}" --context "${FLINK_CONTEXT}" 2>/dev/null) || true

echo "----------------------------------------"
echo "Use case 3: Compute ETA pipeline (database=${FLINK_DATABASE}, context=${FLINK_CONTEXT})"
echo "----------------------------------------"

create_table "${STATEMENT_LIST}" "${TABLE_LIST}" "package_eta_history" "${SQL_DIR}/ddl.package_eta_history.sql"

if ! statement_exists "${STATEMENT_LIST}" "dml-package-eta-history"; then
  confluent flink statement delete 'dml-package-eta-history' --cloud ${CLOUD} --region ${REGION} --environment "${FLINK_ENVIRONMENT}" --context "${FLINK_CONTEXT}" --force
fi
sql_statement=$(cat "${SQL_DIR}/dml.package_eta_history.sql")
confluent -v flink statement create 'dml-package-eta-history' --sql "${sql_statement}" --database "${FLINK_DATABASE}" --compute-pool "${FLINK_COMPUTE_POOL}" --environment "${FLINK_ENVIRONMENT}" --context "${FLINK_CONTEXT}" --wait

if ! statement_exists "${STATEMENT_LIST}" "dml-compute-eta"; then
  confluent flink statement delete 'dml-compute-eta' --cloud ${CLOUD} --region ${REGION} --environment "${FLINK_ENVIRONMENT}" --context "${FLINK_CONTEXT}" --force
fi
sql_statement=$(cat "${SQL_DIR}/dml.compute_eta.sql")
confluent -v flink statement create 'dml-compute-eta' --sql "${sql_statement}" --database "${FLINK_DATABASE}" --compute-pool "${FLINK_COMPUTE_POOL}" --environment "${FLINK_ENVIRONMENT}" --context "${FLINK_CONTEXT}" --wait

echo "Use case 3 deployed."
