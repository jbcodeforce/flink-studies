#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JOBS_DIR="$(cd "$SCRIPT_DIR/../../flink-jobs/sql-executor" && pwd)"
IMAGE="${PERF_OSS_IMAGE:-perf-sql-executor:0.1.0}"

echo "Building sql-executor JAR..."
mvn -f "$JOBS_DIR" clean package -DskipTests -q

cp "$JOBS_DIR/target/perf-sql-executor-0.1.0.jar" "$SCRIPT_DIR/"

echo "Building Docker image $IMAGE..."
docker build -t "$IMAGE" "$SCRIPT_DIR"

rm -f "$SCRIPT_DIR/perf-sql-executor-0.1.0.jar"

echo "Image ready: $IMAGE"
echo "Load into cluster: kind load docker-image $IMAGE  # or minikube image load $IMAGE"
