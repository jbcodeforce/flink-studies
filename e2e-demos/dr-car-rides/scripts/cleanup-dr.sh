#!/usr/bin/env bash
# Reset the DR side to a clean state before re-running a failover. Run from the LAPTOP; the work
# itself runs on the DR bastion (the DR Kafka REST and Flink endpoints are private).
#
#   1. stop every produce_rides.py: on the laptop and on the bastion
#   2. delete the DR Flink statements (dr-dims-rides-clean, dr-facts-driver-stats)
#   3. delete the DR topics rides_clean and driver_stats (created by dbt at failover)
#   4. delete the DR schema subjects rides_clean-* and driver_stats-* (soft, then permanent)
#
# rides_raw (the promoted mirror) and its subjects are kept, unless --include-raw is given:
# then the rides_raw topic is deleted too, which is needed before the mirror is re-created
# (see the end of scripts/failback.sh).
#
# Not done here, run it from the laptop afterwards if the exporter state is stale:
#   cd IaC/03-schema-linking && terraform apply
#
# Usage:
#   AWS_PROFILE=<profile> scripts/cleanup-dr.sh [--yes] [--include-raw] [--reset-seq-log]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ASSUME_YES=0
INCLUDE_RAW=0
RESET_SEQ=0
ON_BASTION=0
STATEMENTS=(dr-dims-rides-clean dr-facts-driver-stats)

while [[ $# -gt 0 ]]; do
  case "$1" in
    --yes) ASSUME_YES=1; shift ;;
    --include-raw) INCLUDE_RAW=1; shift ;;
    --reset-seq-log) RESET_SEQ=1; shift ;;
    --on-bastion) ON_BASTION=1; shift ;;   # internal: set by the laptop side
    *) echo "usage: cleanup-dr.sh [--yes] [--include-raw] [--reset-seq-log]" >&2; exit 2 ;;
  esac
done

step() { echo; echo "[$(date +%H:%M:%S)] $*"; }

# Matches processes whose command line has produce_rides.py as an argument (python, or the uv
# launcher). This script and its parent are excluded. SIGINT first so the producer flushes,
# then SIGKILL.
producer_pids() { pgrep -f "$PRODUCER_RE" | grep -vx -e "$$" -e "$PPID" || true; }
PRODUCER_RE='(^|[ /])produce_rides\.py( |$)'
stop_producers() {
  local pids i
  pids="$(producer_pids)"
  if [[ -z "$pids" ]]; then
    echo "  no produce_rides.py running"
    return 0
  fi
  echo "  stopping produce_rides.py: $(echo "$pids" | tr '\n' ' ')"
  # shellcheck disable=SC2086
  kill -INT $pids 2>/dev/null || true
  for i in $(seq 1 10); do
    pids="$(producer_pids)"
    [[ -z "$pids" ]] && { echo "  stopped"; return 0; }
    sleep 1
  done
  echo "  still running after 10s, sending SIGKILL: $(echo "$pids" | tr '\n' ' ')"
  # shellcheck disable=SC2086
  kill -KILL $pids 2>/dev/null || true
  sleep 1
  [[ -z "$(producer_pids)" ]] || { echo "  produce_rides.py is still running" >&2; return 1; }
  echo "  stopped"
}

# ------------------------------------------------------------------ laptop side
if [[ "$ON_BASTION" -ne 1 ]]; then
  command -v aws >/dev/null || { echo "aws is required" >&2; exit 1; }
  echo "=== DR cleanup ==="
  echo "Deletes on DR: Flink statements ${STATEMENTS[*]}, topics rides_clean + driver_stats,"
  echo "their schema subjects$([[ "$INCLUDE_RAW" -eq 1 ]] && echo ", AND the rides_raw topic (its schemas are kept)")."
  if [[ "$ASSUME_YES" -ne 1 ]]; then
    read -r -p "Proceed? [y/N] " answer
    [[ "$answer" == "y" || "$answer" == "Y" ]] || { echo "Aborted."; exit 1; }
  fi

  step "1/2 Stop the producer on the laptop"
  stop_producers
  if [[ "$RESET_SEQ" -eq 1 ]]; then
    rm -f "${SEQ_LOG:-/tmp/dr-car-rides-seq.log}"
    echo "  removed the laptop seq log"
  fi

  step "2/2 Clean the DR side (on the bastion)"
  remote_args="--on-bastion --yes"
  [[ "$INCLUDE_RAW" -eq 1 ]] && remote_args+=" --include-raw"
  [[ "$RESET_SEQ" -eq 1 ]] && remote_args+=" --reset-seq-log"
  "$SCRIPT_DIR/bastion-sync.sh" -- "scripts/pull-outputs.sh && scripts/cleanup-dr.sh $remote_args"

  echo
  echo "Next: if the exporter still lists extra subjects, re-apply Layer 3 from the laptop:"
  echo "  cd IaC/03-schema-linking && terraform apply"
  exit 0
fi

# ------------------------------------------------------------------ bastion side
for tool in jq curl; do
  command -v "$tool" >/dev/null || { echo "$tool is required" >&2; exit 1; }
done

# shellcheck disable=SC1091
source "$SCRIPT_DIR/export-env.sh" dr >/dev/null

# Credentials go through a curl config on a pipe, not the command line.
acurl() { local key="$1" secret="$2"; shift 2; curl -sS --max-time 60 -K <(printf 'user = "%s:%s"\n' "$key" "$secret") "$@"; }
code_of() { local key="$1" secret="$2"; shift 2; acurl "$key" "$secret" -o /dev/null -w '%{http_code}' "$@" || echo 000; }

FAILED=0
FLINK_BASE="${FLINK_ENDPOINT:-$FLINK_REST_ENDPOINT}"
statement_url() { echo "$FLINK_BASE/sql/v1/organizations/$ORGANIZATION_ID/environments/$CONFLUENT_ENVIRONMENT_ID/statements/$1"; }
topic_url() { echo "$KAFKA_REST_ENDPOINT/kafka/v3/clusters/$KAFKA_CLUSTER_ID/topics/$1"; }

step "Bastion: stop the producer"
stop_producers || FAILED=1
if [[ "$RESET_SEQ" -eq 1 ]]; then
  rm -f "$SEQ_LOG"
  echo "  removed the bastion seq log ($SEQ_LOG)"
fi

step "Bastion: delete the DR Flink statements"
for s in "${STATEMENTS[@]}"; do
  c="$(code_of "$FLINK_API_KEY" "$FLINK_API_SECRET" -X DELETE "$(statement_url "$s")")"
  case "$c" in
    200|202|204) echo "  $s: delete requested" ;;
    404) echo "  $s: not found" ;;
    *) echo "  $s: delete failed (HTTP $c)" >&2; FAILED=1 ;;
  esac
done
# A running statement would re-create the topics we delete next: wait until they are gone.
for s in "${STATEMENTS[@]}"; do
  for _ in $(seq 1 30); do
    [[ "$(code_of "$FLINK_API_KEY" "$FLINK_API_SECRET" "$(statement_url "$s")")" == "404" ]] && break
    sleep 2
  done
  [[ "$(code_of "$FLINK_API_KEY" "$FLINK_API_SECRET" "$(statement_url "$s")")" == "404" ]] \
    || { echo "  $s: still present after 60s" >&2; FAILED=1; }
done

step "Bastion: delete the DR topics"
topics=(rides_clean driver_stats)
[[ "$INCLUDE_RAW" -eq 1 ]] && topics+=(rides_raw)
for t in "${topics[@]}"; do
  c="$(code_of "$KAFKA_API_KEY" "$KAFKA_API_SECRET" -X DELETE "$(topic_url "$t")")"
  case "$c" in
    200|202|204) echo "  $t: deleted" ;;
    404) echo "  $t: not found" ;;
    *) echo "  $t: delete failed (HTTP $c)" >&2; FAILED=1 ;;
  esac
done

step "Bastion: delete the DR schema subjects (soft, then permanent)"
for sub in rides_clean-key rides_clean-value driver_stats-key driver_stats-value; do
  # The soft delete is a 404 when the subject is already soft-deleted; the permanent one still applies.
  code_of "$SCHEMA_REGISTRY_API_KEY" "$SCHEMA_REGISTRY_API_SECRET" -X DELETE "$SCHEMA_REGISTRY_ENDPOINT/subjects/$sub" >/dev/null
  c="$(code_of "$SCHEMA_REGISTRY_API_KEY" "$SCHEMA_REGISTRY_API_SECRET" -X DELETE "$SCHEMA_REGISTRY_ENDPOINT/subjects/$sub?permanent=true")"
  case "$c" in
    200) echo "  $sub: permanently deleted" ;;
    404) echo "  $sub: not found" ;;
    *) echo "  $sub: delete failed (HTTP $c)" >&2; FAILED=1 ;;
  esac
done

echo
if [[ "$FAILED" -ne 0 ]]; then
  echo "Cleanup finished with errors (see above)." >&2
  exit 1
fi
echo "DR cleanup complete."
