#!/usr/bin/env bash
# Build producer and Flink job JARs for perf-testing.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SKIP_TESTS="${SKIP_TESTS:-false}"

MVN_ARGS=(clean package)
if [[ "$SKIP_TESTS" == "true" ]]; then
  MVN_ARGS+=(-DskipTests)
fi

echo "Building perf-testing components (Flink 2.2.0)..."
mvn -f "$ROOT/producer" "${MVN_ARGS[@]}"
mvn -f "$ROOT/flink-jobs/sql-executor" "${MVN_ARGS[@]}"
mvn -f "$ROOT/flink-jobs/datastream" "${MVN_ARGS[@]}"
echo "Done. JARs:"
echo "  $ROOT/producer/target/perf-data-generator-0.1.0.jar"
echo "  $ROOT/flink-jobs/sql-executor/target/perf-sql-executor-0.1.0.jar"
echo "  $ROOT/flink-jobs/datastream/target/perf-datastream-job-0.1.0.jar"
