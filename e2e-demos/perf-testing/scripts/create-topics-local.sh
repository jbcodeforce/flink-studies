#!/usr/bin/env bash
# Create perf-input and perf-output topics using kafka-topics CLI.
set -euo pipefail

if [[ -z "${BOOTSTRAP_SERVERS:-}" ]]; then
  echo "BOOTSTRAP_SERVERS is required (e.g. localhost:9092)"
  exit 1
fi

PARTITIONS="${PARTITIONS:-3}"
REPLICATION="${REPLICATION:-1}"
INPUT_TOPIC="${INPUT_TOPIC:-perf-input}"
OUTPUT_TOPIC="${OUTPUT_TOPIC:-perf-output}"

create_topic() {
  local topic="$1"
  if kafka-topics --bootstrap-server "$BOOTSTRAP_SERVERS" --list 2>/dev/null | grep -qx "$topic"; then
    echo "Topic exists: $topic"
  else
    echo "Creating topic: $topic (partitions=$PARTITIONS replication=$REPLICATION)"
    kafka-topics --bootstrap-server "$BOOTSTRAP_SERVERS" \
      --create --topic "$topic" \
      --partitions "$PARTITIONS" \
      --replication-factor "$REPLICATION"
  fi
}

create_topic "$INPUT_TOPIC"
create_topic "$OUTPUT_TOPIC"
echo "Topics ready: $INPUT_TOPIC, $OUTPUT_TOPIC"
