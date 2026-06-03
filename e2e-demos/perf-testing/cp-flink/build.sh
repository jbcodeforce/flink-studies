#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JOBS_DIR="$(cd "$SCRIPT_DIR/../flink-jobs/sql-executor" && pwd)"
IMAGE="${PERF_CP_IMAGE:-perf-sql-executor-cp:0.1.0}"

mvn -f "$JOBS_DIR" clean package -DskipTests -q
cp "$JOBS_DIR/target/perf-sql-executor-0.1.0.jar" "$SCRIPT_DIR/"

docker build -t "$IMAGE" "$SCRIPT_DIR"
rm -f "$SCRIPT_DIR/perf-sql-executor-0.1.0.jar"

echo "Image ready: $IMAGE"
