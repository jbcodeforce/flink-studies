#!/usr/bin/env bash
set -e 
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/package_event_cutoff_lib.sh"

STATEMENT_LIST=$(confluent flink statement list -o json --cloud "${CLOUD}" --region "${REGION}" --compute-pool "${FLINK_COMPUTE_POOL}" --environment "${FLINK_ENVIRONMENT}" --context "${FLINK_CONTEXT}" 2>/dev/null) || true

if ! statement_exists "${STATEMENT_LIST}" "dml-package-events-on-expected-ts-change"; then
  confluent flink statement delete 'dml-package-events-on-expected-ts-change' --cloud ${CLOUD} --region ${REGION} --environment "${FLINK_ENVIRONMENT}" --context "${FLINK_CONTEXT}" --force
fi

if ! statement_exists "${STATEMENT_LIST}" "insert-package-events"; then
    confluent flink statement delete 'insert-package-events' --cloud ${CLOUD} --region ${REGION} --environment "${FLINK_ENVIRONMENT}" --context "${FLINK_CONTEXT}" --force
fi

if ! statement_exists "${STATEMENT_LIST}" "ddl-package-events"; then
    confluent flink statement delete 'ddl-package-events' --cloud ${CLOUD} --region ${REGION} --environment "${FLINK_ENVIRONMENT}" --context "${FLINK_CONTEXT}" --force
fi

if ! statement_exists "${STATEMENT_LIST}" "ddl-last-expected-ts-package-events"; then
    confluent flink statement delete 'ddl-last-expected-ts-package-events' --cloud ${CLOUD} --region ${REGION} --environment "${FLINK_ENVIRONMENT}" --context "${FLINK_CONTEXT}" --force
fi
if ! statement_exists "${STATEMENT_LIST}" "drop-last-expected-ts-package-events"; then
    confluent flink statement delete 'drop-last-expected-ts-package-events' --cloud ${CLOUD} --region ${REGION} --environment "${FLINK_ENVIRONMENT}" --context "${FLINK_CONTEXT}" --force
fi

confluent flink statement create "drop-package-events" --sql "drop table package_events" --database "${FLINK_DATABASE}" --compute-pool "${FLINK_COMPUTE_POOL}" --environment "${FLINK_ENVIRONMENT}" --context "${FLINK_CONTEXT}" --wait
confluent flink statement delete 'drop-package-events' --cloud ${CLOUD} --region ${REGION} --environment "${FLINK_ENVIRONMENT}" --context "${FLINK_CONTEXT}" --force


confluent flink statement create "drop-sink-table" --sql "drop table last_expected_ts_package_events" --database "${FLINK_DATABASE}" --compute-pool "${FLINK_COMPUTE_POOL}" --environment "${FLINK_ENVIRONMENT}" --context "${FLINK_CONTEXT}" --wait
confluent flink statement delete 'drop-sink-table' --cloud ${CLOUD} --region ${REGION} --environment "${FLINK_ENVIRONMENT}" --context "${FLINK_CONTEXT}" --force


# scenario 2 assets
if ! statement_exists "${STATEMENT_LIST}" "dml-package-morning-cutoff"; then
  confluent flink statement delete 'dml-package-morning-cutoff' --cloud ${CLOUD} --region ${REGION} --environment "${FLINK_ENVIRONMENT}" --context "${FLINK_CONTEXT}" --force
fi

if ! statement_exists "${STATEMENT_LIST}" "drop-enhanced-package-events"; then
    confluent flink statement delete 'drop-enhanced-package-events' --cloud ${CLOUD} --region ${REGION} --environment "${FLINK_ENVIRONMENT}" --context "${FLINK_CONTEXT}" --force
fi

confluent flink statement create "drop-sink-table-2" --sql "drop table enhanced_package_events" --database "${FLINK_DATABASE}" --compute-pool "${FLINK_COMPUTE_POOL}" --environment "${FLINK_ENVIRONMENT}" --context "${FLINK_CONTEXT}" --wait
confluent flink statement delete 'drop-sink-table-2' --cloud ${CLOUD} --region ${REGION} --environment "${FLINK_ENVIRONMENT}" --context "${FLINK_CONTEXT}" --force
