#!/usr/bin/env sh
# Load the demo topic from the host (PLAINTEXT_HOST on port 9092, same as kafka-topic-consumer-offsets).
set -e
cd "$(dirname "$0")/.."
ROOT=$(pwd)
export KAFKA_BOOTSTRAP="${KAFKA_BOOTSTRAP:-localhost:9092}"
export KAFKA_TOPIC="${KAFKA_TOPIC:-watermark_demo}"
uv sync --group dev
uv run flink-wm-produce --bootstrap "$KAFKA_BOOTSTRAP" --topic "$KAFKA_TOPIC"
echo "Kafka load done ($ROOT)."
