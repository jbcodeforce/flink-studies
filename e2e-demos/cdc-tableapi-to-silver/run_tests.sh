#!/usr/bin/env bash
# Run test data and validation for cdc-tableapi-to-silver demo.
# Red phase: run without pipeline -> validations fail.
# Green phase: apply DDL/DML (raw, silver, dim_account, fct_transactions) then run -> expect PASS.
#
# Prerequisites: DDL and DML applied (raw tables, silver, dimension, fact). Optional: FLINK_VALIDATE_CMD
# to run validation SQL (e.g. confluent flink statement create ... --sql "$(cat tests/validate_*.sql)").
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RAW_DIR="${SCRIPT_DIR}/raw_topic_for_tests"
TESTS_DIR="${SCRIPT_DIR}/tests"

echo "CDC Table API to Silver - test runner"
echo "Raw DDL and insert scripts: ${RAW_DIR}"
echo "Validation SQL: ${TESTS_DIR}"

if [ -n "${FLINK_VALIDATE_CMD}" ]; then
  echo "Running dimension validation (validate_dim_account_1.sql)..."
  dim_result="$($FLINK_VALIDATE_CMD "${TESTS_DIR}/validate_dim_account_1.sql" 2>/dev/null || true)"
  if echo "$dim_result" | grep -q "PASS"; then
    echo "dim_account: PASS"
  else
    echo "dim_account: FAIL (or table not found)"
    echo "$dim_result"
  fi

  echo "Running fact validation (validate_fct_transactions_1.sql)..."
  fct_result="$($FLINK_VALIDATE_CMD "${TESTS_DIR}/validate_fct_transactions_1.sql" 2>/dev/null || true)"
  if echo "$fct_result" | grep -q "PASS"; then
    echo "fct_transactions: PASS"
  else
    echo "fct_transactions: FAIL (or table not found)"
    echo "$fct_result"
  fi

  if echo "$dim_result" | grep -q "PASS" && echo "$fct_result" | grep -q "PASS"; then
    echo "Result: ALL PASS"
    exit 0
  else
    echo "Result: FAIL"
    exit 1
  fi
else
  echo "FLINK_VALIDATE_CMD not set. Apply DDL/DML, then run validation SQL manually:"
  echo "  ${TESTS_DIR}/validate_dim_account_1.sql"
  echo "  ${TESTS_DIR}/validate_fct_transactions_1.sql"
  echo "Expect one row per query with test_result = 'PASS'."
  exit 0
fi
