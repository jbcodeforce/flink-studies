#!/usr/bin/env bash
# Submit a Flink perf job. Requires BOOTSTRAP_SERVERS and flink on PATH.
# Usage: ./run-flink-job.sh sql-executor|datastream
# Env: FLINK_HOME or flink in PATH; BOOTSTRAP_SERVERS; INPUT_TOPIC, OUTPUT_TOPIC (optional).

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JOBS_DIR="$(cd "$SCRIPT_DIR/../flink-jobs" && pwd)"
JOB_TYPE="${1:-sql-executor}"

if [[ -z "$BOOTSTRAP_SERVERS" ]]; then
  echo "BOOTSTRAP_SERVERS is required"
  exit 1
fi

export INPUT_TOPIC="${INPUT_TOPIC:-perf-input}"
export OUTPUT_TOPIC="${OUTPUT_TOPIC:-perf-output}"

case "$JOB_TYPE" in
  sql-executor)
    JAR="$JOBS_DIR/sql-executor/target/perf-sql-executor-0.1.0.jar"
    if [[ ! -f "$JAR" ]]; then
      echo "Sql-executor JAR not found. Build with: mvn -f $JOBS_DIR/sql-executor clean package"
      exit 1
    fi
    exec flink run "$JAR"
    ;;
  datastream)
    JAR="$JOBS_DIR/datastream/target/perf-datastream-job-0.1.0.jar"
    if [[ ! -f "$JAR" ]]; then
      echo "Datastream JAR not found. Build with: mvn -f $JOBS_DIR/datastream clean package"
      exit 1
    fi
    exec flink run "$JAR"
    ;;
  *)
    echo "Usage: $0 sql-executor|datastream"
    exit 1
    ;;
esac
