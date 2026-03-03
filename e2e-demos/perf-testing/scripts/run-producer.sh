#!/usr/bin/env bash
# Run the perf data generator JAR. Requires BOOTSTRAP_SERVERS.
# Optional env: TOPIC, RATE_PER_SEC, MESSAGE_SIZE_BYTES, DURATION_SECONDS, NUM_THREADS.
# Optional args: rate duration (e.g. ./run-producer.sh 5000 120)

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PRODUCER_DIR="$(cd "$SCRIPT_DIR/../producer" && pwd)"
JAR="${PRODUCER_JAR:-$PRODUCER_DIR/target/perf-data-generator-0.1.0.jar}"

if [[ ! -f "$JAR" ]]; then
  echo "Producer JAR not found. Build with: mvn -f $PRODUCER_DIR clean package"
  exit 1
fi

if [[ -z "$BOOTSTRAP_SERVERS" ]]; then
  echo "BOOTSTRAP_SERVERS is required"
  exit 1
fi

RATE="${1:-${RATE_PER_SEC:-1000}}"
DURATION="${2:-${DURATION_SECONDS:-60}}"
export RATE_PER_SEC="$RATE"
export DURATION_SECONDS="$DURATION"

echo "Running producer: rate=$RATE msg/s duration=${DURATION}s"
exec java -jar "$JAR" "${TOPIC:-perf-input}" "$RATE" "${MESSAGE_SIZE_BYTES:-256}" "$DURATION" "${NUM_THREADS:-1}"
