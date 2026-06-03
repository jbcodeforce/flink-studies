#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

"${ROOT}/oss-flink/flink-sql-executor/build.sh"

echo "Applying FlinkDeployment..."
kubectl apply -f "${ROOT}/oss-flink/k8s/flink-deployment.yaml"

echo "Waiting for FlinkDeployment (timeout 300s)..."
kubectl wait --for=condition=Ready flinkdeployment/perf-sql-executor -n flink --timeout=300s 2>/dev/null \
  || kubectl get flinkdeployment -n flink

echo "OSS deploy submitted. Port-forward UI: kubectl port-forward svc/perf-sql-executor-rest 8081:8081 -n flink"
