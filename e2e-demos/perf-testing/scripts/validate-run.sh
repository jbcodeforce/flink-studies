#!/usr/bin/env bash
# Smoke-check that perf-output received records from the Flink job.
set -euo pipefail

if [[ -z "${BOOTSTRAP_SERVERS:-}" ]]; then
  echo "BOOTSTRAP_SERVERS is required"
  exit 1
fi

OUTPUT_TOPIC="${OUTPUT_TOPIC:-perf-output}"
MIN_MESSAGES="${MIN_MESSAGES:-1}"
TIMEOUT_MS="${TIMEOUT_MS:-15000}"

echo "Consuming up to $MIN_MESSAGES message(s) from $OUTPUT_TOPIC (timeout ${TIMEOUT_MS}ms)..."

if command -v kafka-console-consumer &>/dev/null; then
  OUT="$(timeout 30 kafka-console-consumer \
    --bootstrap-server "$BOOTSTRAP_SERVERS" \
    --topic "$OUTPUT_TOPIC" \
    --from-beginning \
    --max-messages "$MIN_MESSAGES" \
    --timeout-ms "$TIMEOUT_MS" 2>/dev/null || true)"
elif command -v kcat &>/dev/null; then
  OUT="$(kcat -C -b "$BOOTSTRAP_SERVERS" -t "$OUTPUT_TOPIC" -o beginning -c "$MIN_MESSAGES" -e 2>/dev/null || true)"
else
  echo "Install kafka-console-consumer (Kafka distribution) or kcat to validate output."
  exit 1
fi

COUNT="$(echo "$OUT" | grep -c . || true)"
if [[ "$COUNT" -lt "$MIN_MESSAGES" ]]; then
  echo "Validation failed: expected at least $MIN_MESSAGES message(s), got $COUNT"
  echo "Ensure the Flink job is running and the producer has written to perf-input."
  exit 1
fi

echo "Validation OK: received at least $MIN_MESSAGES message(s) on $OUTPUT_TOPIC"
echo "Sample:"
echo "$OUT" | head -n 1
