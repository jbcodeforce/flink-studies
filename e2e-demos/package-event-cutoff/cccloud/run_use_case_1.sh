#!/usr/bin/env bash
# Deploy use case 1: emit to sink only when expected_ts changes per package_id.
# Order: DDL (package_events), DDL (sink last_expected_ts_package_events), insert test data, DML.

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

# Get list of tables (for conditional drop) and list of statements (for conditional delete)
TABLE_LIST=$(get_table_list)

STATEMENT_LIST=$(confluent flink statement list -o json --cloud "${CLOUD}" --region "${REGION}" --compute-pool "${FLINK_COMPUTE_POOL}" --environment "${FLINK_ENVIRONMENT}" --context "${FLINK_CONTEXT}" 2>/dev/null) || true

echo "----------------------------------------"
echo "Use case 1: expected_ts change pipeline (database=${FLINK_DATABASE}, context=${FLINK_CONTEXT})"
echo "----------------------------------------"
# statement list, table list, table name, ddl sql file
create_table "${STATEMENT_LIST}" "${TABLE_LIST}" "package_events" "${SQL_DIR}/ddl.package_events.sql"

create_table "${STATEMENT_LIST}" "${TABLE_LIST}" "last_expected_ts_package_events" "${SQL_DIR}/ddl.last_expected_ts_package_events.sql"


if ! statement_exists "${STATEMENT_LIST}" "insert-package-events"; then
  confluent flink statement delete 'insert-package-events' --cloud ${CLOUD} --region ${REGION} --environment "${FLINK_ENVIRONMENT}" --context "${FLINK_CONTEXT}" --force
fi
sql_statement=$(cat "${TESTS_DIR}/insert_package_events.sql")
confluent -v flink statement create 'insert-package-events' --sql "${sql_statement}" --database "${FLINK_DATABASE}" --compute-pool "${FLINK_COMPUTE_POOL}" --environment "${FLINK_ENVIRONMENT}" --context "${FLINK_CONTEXT}" --wait

if ! statement_exists "${STATEMENT_LIST}" "dml-package-events-on-expected-ts-change"; then
  confluent flink statement delete 'dml-package-events-on-expected-ts-change' --cloud ${CLOUD} --region ${REGION} --environment "${FLINK_ENVIRONMENT}" --context "${FLINK_CONTEXT}" --force
fi
sql_statement=$(cat "${SQL_DIR}/dml.package_events_on_expected_ts_change.sql")
confluent -v flink statement create 'dml-package-events-on-expected-ts-change' --sql "${sql_statement}" --database "${FLINK_DATABASE}" --compute-pool "${FLINK_COMPUTE_POOL}" --environment "${FLINK_ENVIRONMENT}" --context "${FLINK_CONTEXT}" --wait

echo "Use case 1 deployed."
