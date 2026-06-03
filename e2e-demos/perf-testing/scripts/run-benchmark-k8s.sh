#!/usr/bin/env bash
# Orchestrate a K8s perf run: topics, Flink deploy, producer Job, validate.
set -euo pipefail

TARGET="${1:-cp}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

if [[ -z "${BOOTSTRAP_SERVERS:-}" ]]; then
  echo "Set BOOTSTRAP_SERVERS to a reachable bootstrap (e.g. localhost:9092 after port-forward)."
  exit 1
fi

case "$TARGET" in
  oss)
    "${SCRIPT_DIR}/deploy-k8s-oss.sh"
    ;;
  cp)
    "${SCRIPT_DIR}/deploy-k8s-cp.sh"
    ;;
  *)
    echo "Usage: $0 cp|oss"
    exit 1
    ;;
esac

echo "Deploying producer Job..."
kubectl apply -f "${ROOT}/producer/k8s/configmap.yaml"
kubectl delete job perf-producer --ignore-not-found
kubectl apply -f "${ROOT}/producer/k8s/job.yaml"

echo "Waiting for producer to finish..."
kubectl wait --for=condition=complete job/perf-producer --timeout=600s 2>/dev/null || true

"${SCRIPT_DIR}/validate-run.sh"
