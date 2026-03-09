# Shared functions for package-event-cutoff use case scripts.
# Source this file from run_use_case_1.sh and run_use_case_2.sh.
# Callers must set: FLINK_ENVIRONMENT, FLINK_CONTEXT, FLINK_COMPUTE_POOL, FLINK_DATABASE,
# and for create_table/get_table_list: CLOUD, REGION, KAFKA_CLUSTER (for get_table_list).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Shared SQL and tests live at demo root
SQL_DIR="${SCRIPT_DIR}/../sql-scripts"
TESTS_DIR="${SCRIPT_DIR}/../tests"

FLINK_DATABASE="${FLINK_DATABASE:-j9r-kafka}"
KAFKA_CLUSTER="${KAFKA_CLUSTER:-lkc-7v233w}"
FLINK_COMPUTE_POOL="${FLINK_COMPUTE_POOL:-lfcp-n7jzzz}"
FLINK_ENVIRONMENT="${FLINK_ENVIRONMENT:-env-yk3jm6}"
CLOUD="${CLOUD:-aws}"
REGION="${REGION:-us-west-2}"

# Returns 0 if statement name is not in the list; returns 1 if it exists (does not exit).
statement_exists() {
  local statement_list="$1"
  local check_name="$2"
  local exists=""
  if command -v jq >/dev/null 2>&1; then
    exists=$(echo "${statement_list}" | jq -r --arg n "${check_name}" '(if type == "array" then . else (.statements // []) end) | .[] | select(.name == $n) | .name' 2>/dev/null | head -1)
  else
    exists=$(echo "${statement_list}" | grep -q "\"name\"[[:space:]]*:[[:space:]]*\"${check_name}\"" 2>/dev/null && echo "${check_name}" || true)
  fi
  if [ -n "${exists}" ]; then
    echo "Statement '${check_name}' already exists." >&2
    return 1
  fi
  return 0
}

# Outputs list of names (one per line) from confluent kafka topic list -o json.
# Uses global: KAFKA_CLUSTER, FLINK_ENVIRONMENT, FLINK_CONTEXT.
get_table_list() {
  local resp
  resp=$(confluent kafka topic list --cluster "${KAFKA_CLUSTER}" --environment "${FLINK_ENVIRONMENT}" --context "${FLINK_CONTEXT}" -o json 2>/dev/null) || true
  echo "${resp}" | jq -r '.[].name'
}

# Returns 0 if table_name is in table_list (one name per line), 1 otherwise.
table_exists() {
  local table_list="$1"
  local table_name="$2"
  echo "${table_list}" | grep -qFx "${table_name}"
}

# Deploy a table's DDL: optionally drop table if it exists (via drop statement), then create statement from SQL file.
# Args: statement_list, table_list, table_name, ddl_sql_file
# Uses global: CLOUD, REGION, FLINK_ENVIRONMENT, FLINK_CONTEXT, FLINK_DATABASE, FLINK_COMPUTE_POOL
create_table() {
  local statement_list="$1"
  local table_list="$2"
  local table_name="$3"
  local ddl_sql_file="$4"
  local stmt_name drop_stmt_name ddl_stmt_name sql_statement
  stmt_name=$(echo "${table_name}" | tr '_' '-')
  drop_stmt_name="drop-${stmt_name}"
  ddl_stmt_name="ddl-${stmt_name}"
  if ! statement_exists "${statement_list}" "${drop_stmt_name}"; then
    confluent flink statement delete "${drop_stmt_name}" --cloud "${CLOUD}" --region "${REGION}" --environment "${FLINK_ENVIRONMENT}" --context "${FLINK_CONTEXT}" --force
  fi
  if table_exists "${table_list}" "${table_name}"; then
    confluent flink statement create "${drop_stmt_name}" --sql "drop table ${table_name}" --database "${FLINK_DATABASE}" --compute-pool "${FLINK_COMPUTE_POOL}" --environment "${FLINK_ENVIRONMENT}" --context "${FLINK_CONTEXT}" --wait
  fi
  if ! statement_exists "${statement_list}" "${ddl_stmt_name}"; then
    confluent flink statement delete "${ddl_stmt_name}"  --cloud "${CLOUD}" --region "${REGION}"  --environment "${FLINK_ENVIRONMENT}" --context "${FLINK_CONTEXT}"  --force
  fi
  sql_statement=$(cat "${ddl_sql_file}")
  confluent flink statement create "${ddl_stmt_name}" --sql "${sql_statement}" --database "${FLINK_DATABASE}" --compute-pool "${FLINK_COMPUTE_POOL}" --environment "${FLINK_ENVIRONMENT}" --context "${FLINK_CONTEXT}" --wait
}
