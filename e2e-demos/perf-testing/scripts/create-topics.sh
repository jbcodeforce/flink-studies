#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
K8S_DIR="$SCRIPT_DIR/../k8s"

kubectl apply -f "$K8S_DIR/perf-input.yaml" -n kafka
kubectl apply -f "$K8S_DIR/perf-output.yaml" -n kafka