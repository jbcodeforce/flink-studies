#!/usr/bin/env sh
# Wait until the Flink JobManager HTTP port answers (avoids a race after compose up).
set -e
i=0
while [ "$i" -lt 60 ]; do
  if curl -sf "http://127.0.0.1:8081/overview" >/dev/null 2>&1; then
    echo "Flink JobManager is up."
    exit 0
  fi
  i=$((i + 1))
  sleep 2
done
echo "Timeout waiting for Flink on :8081" >&2
exit 1
