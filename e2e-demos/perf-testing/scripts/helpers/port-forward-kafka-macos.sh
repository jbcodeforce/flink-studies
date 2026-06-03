#!/usr/bin/env bash
# Optional (macOS): open a Terminal window with kubectl port-forward to Kafka.
if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "This helper is macOS-only. On Linux run:"
  echo "  kubectl port-forward svc/kafka 9092:9092 -n kafka"
  exit 0
fi

NS="${KAFKA_NAMESPACE:-kafka}"
SVC="${KAFKA_SERVICE:-kafka}"
osascript -e "tell app \"Terminal\" to do script \"kubectl port-forward svc/${SVC} 9092:9092 -n ${NS}\""
