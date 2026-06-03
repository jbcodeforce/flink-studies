#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

"${ROOT}/cp-flink/build.sh"

echo "Applying Kafka topics (CP operator)..."
"${SCRIPT_DIR}/create-topics.sh"

echo "Applying CMF FlinkApplication..."
kubectl apply -f "${ROOT}/cp-flink/k8s/flink-application.yaml"

echo "CP deploy submitted. Check: kubectl get flinkapplication -n flink"
