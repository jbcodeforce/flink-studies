#!/usr/bin/env bash
# Promote / fail-over mirror topics on DR, then start Flink on DR.
# Requires Confluent CLI and Kafka REST credentials from export-env.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/export-env.sh" dr

TOPICS=(rides_raw rides_clean driver_stats)
LINK="${CLUSTER_LINK_NAME:-dr-rides-bidirectional}"

echo "=== Promote failover (mirror topics) ==="
echo "Cluster: $KAFKA_CLUSTER_ID  link: $LINK"
echo

if ! command -v confluent >/dev/null 2>&1; then
  echo "Confluent CLI required for promote path." >&2
  echo "Manual: Cloud UI → Cluster Linking → promote/fail over mirrors for: ${TOPICS[*]}" >&2
  exit 1
fi

for topic in "${TOPICS[@]}"; do
  echo "Promoting mirror topic: $topic"
  # CLI surface varies by version; try promote then failover.
  if confluent kafka mirror promote "$topic" --link "$LINK" --cluster "$KAFKA_CLUSTER_ID" 2>/dev/null; then
    echo "  promoted $topic"
  elif confluent kafka mirror failover "$topic" --link "$LINK" --cluster "$KAFKA_CLUSTER_ID" 2>/dev/null; then
    echo "  failed-over $topic"
  else
    echo "  CLI promote/failover failed for $topic — set status via Terraform or UI:"
    echo "    confluent_kafka_mirror_topic status = PROMOTED | FAILED_OVER"
  fi
done

echo
echo "Starting DR Flink via soft-failover deploy path..."
"$SCRIPT_DIR/failover-soft.sh"

echo
echo "Promote failover steps finished. Verify mirrors are writable and Flink is RUNNING on DR."
