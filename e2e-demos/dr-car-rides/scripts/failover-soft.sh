#!/usr/bin/env bash
# Soft (planned) failover primary -> DR. Run from the LAPTOP; only the DR Kafka REST step
# goes through the bastion (the DR cluster is private).
#
#   1. stop the primary Flink statements            (laptop, public Flink API)
#   2. check schemas are on DR, pause the exporter, (laptop, public Schema Registry)
#      set DR Schema Registry IMPORT -> READWRITE
#   3. promote the rides_raw mirror topic           (bastion, DR Kafka REST over PrivateLink)
#   4. deploy the dbt models on DR                  (bastion, private Flink endpoint)
#
# Stop the producer BEFORE running this (Ctrl-C), so the mirrors can drain to lag 0.
#
# Usage:
#   AWS_PROFILE=<profile> scripts/failover-soft.sh [--yes] [--seq-log FILE] [--skip-deploy]
# Prints the RTO (all four steps) and the commands for the DR producer and the loss assessment.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SEQ_LOG="${SEQ_LOG:-/tmp/dr-car-rides-seq.log}"
STATEMENTS=(dr-dims-rides-clean dr-facts-driver-stats)
SUBJECTS=(rides_raw-key rides_raw-value)   # the only exported subjects; dbt registers the others on DR
ASSUME_YES=0
SKIP_DEPLOY=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --yes) ASSUME_YES=1; shift ;;
    --seq-log) SEQ_LOG="${2:?}"; shift 2 ;;
    --skip-deploy) SKIP_DEPLOY=1; shift ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done

for tool in jq curl aws uv; do
  command -v "$tool" >/dev/null || { echo "$tool is required" >&2; exit 1; }
done

# Run a function with ONE site's variables, in a subshell, so primary and DR never mix.
with_site() { local site="$1"; shift; ( source "$SCRIPT_DIR/export-env.sh" "$site" >/dev/null; "$@" ); }
# Basic-auth credentials come from a curl config on a pipe, never from the command line.
acurl() { local key="$1" secret="$2"; shift 2; curl -sS --max-time 60 -K <(printf 'user = "%s:%s"\n' "$key" "$secret") "$@"; }
step() { echo; echo "[$(date +%H:%M:%S)] $*"; }

statement_url() { echo "$FLINK_REST_ENDPOINT/sql/v1/organizations/$ORGANIZATION_ID/environments/$CONFLUENT_ENVIRONMENT_ID/statements/$1"; }

stop_primary_statements() {
  local name phase
  for name in "${STATEMENTS[@]}"; do
    acurl "$FLINK_API_KEY" "$FLINK_API_SECRET" -X PATCH -H 'Content-Type: application/json' \
      -d '{"spec":{"stopped":true}}' "$(statement_url "$name")" >/dev/null
  done
  for name in "${STATEMENTS[@]}"; do
    for _ in $(seq 1 30); do
      phase="$(acurl "$FLINK_API_KEY" "$FLINK_API_SECRET" "$(statement_url "$name")" | jq -r '.status.phase // "UNKNOWN"')"
      [[ "$phase" == "STOPPED" || "$phase" == "COMPLETED" ]] && break
      sleep 2
    done
    echo "  $name: $phase"
    [[ "$phase" == "STOPPED" || "$phase" == "COMPLETED" ]] || { echo "statement did not stop: $name" >&2; return 1; }
  done
}

subject_ids() {
  local s
  for s in "${SUBJECTS[@]}"; do
    echo "$s $(acurl "$SCHEMA_REGISTRY_API_KEY" "$SCHEMA_REGISTRY_API_SECRET" "$SCHEMA_REGISTRY_ENDPOINT/subjects/$s/versions/latest" | jq -r '"\(.id)/\(.version)"')"
  done
}

pause_exporter() {
  acurl "$SCHEMA_REGISTRY_API_KEY" "$SCHEMA_REGISTRY_API_SECRET" -X PUT \
    "$SCHEMA_REGISTRY_ENDPOINT/exporters/$SCHEMA_EXPORTER_NAME/pause" | jq -c '.' 2>/dev/null || true
  acurl "$SCHEMA_REGISTRY_API_KEY" "$SCHEMA_REGISTRY_API_SECRET" \
    "$SCHEMA_REGISTRY_ENDPOINT/exporters/$SCHEMA_EXPORTER_NAME/status" | jq -r '"  exporter state: \(.state)"'
}

dr_registry_readwrite() {
  acurl "$SCHEMA_REGISTRY_API_KEY" "$SCHEMA_REGISTRY_API_SECRET" -X PUT -H 'Content-Type: application/json' \
    -d '{"mode":"READWRITE"}' "$SCHEMA_REGISTRY_ENDPOINT/mode" | jq -r '"  DR registry mode: \(.mode // .message)"'
}

# The DR Flink endpoint is private (PrivateLink): dbt must run on the bastion, with the
# project-local profile (pipelines/profiles.yml, target dr, FLINK_ENDPOINT from export-env.sh).
deploy_dr() {
  "$SCRIPT_DIR/bastion-sync.sh" -- "scripts/pull-outputs.sh && source scripts/export-env.sh dr >/dev/null && cd pipelines && uv run dbt run --profiles-dir . --target dr"
}

echo "=== Soft failover: primary -> DR ==="
if [[ -s "$SEQ_LOG" ]]; then
  PRE_MAX="$(jq -s 'map(.seq) | max' "$SEQ_LOG")"
  echo "Producer high-water seq (from $SEQ_LOG): $PRE_MAX"
else
  PRE_MAX=""
  echo "No seq log at $SEQ_LOG: the loss assessment will not have a producer high-water."
fi
echo "Make sure the producer is STOPPED, otherwise the mirrors cannot drain."
if [[ "$ASSUME_YES" -ne 1 ]]; then
  read -r -p "Proceed with the failover? [y/N] " answer
  [[ "$answer" == "y" || "$answer" == "Y" ]] || { echo "Aborted."; exit 1; }
fi

T0=$SECONDS

step "1/4 Stop the primary Flink statements"
with_site primary stop_primary_statements

step "2/4 Schema Registry: verify ids on DR, pause the exporter, DR -> READWRITE"
P_IDS="$(with_site primary subject_ids)"
D_IDS="$(with_site dr subject_ids)"
if [[ "$P_IDS" != "$D_IDS" ]]; then
  echo "Schema ids differ between primary and DR; refusing to continue:" >&2
  diff <(echo "$P_IDS") <(echo "$D_IDS") >&2 || true
  exit 1
fi
echo "  all ${#SUBJECTS[@]} subjects have identical id/version on both sites"
with_site primary pause_exporter
with_site dr dr_registry_readwrite

step "3/4 Promote the mirror topics (on the bastion)"
"$SCRIPT_DIR/bastion-sync.sh" -- "scripts/pull-outputs.sh && scripts/failover-promote.sh"

if [[ "$SKIP_DEPLOY" -eq 1 ]]; then
  step "4/4 dbt deploy on DR skipped (--skip-deploy)"
else
  step "4/4 Deploy the dbt models on DR (on the bastion, private Flink endpoint)"
  deploy_dr
fi

RTO=$((SECONDS - T0))
step "Done. Failover took ${RTO}s (stop primary statements -> DR statements submitted)"
echo
echo "Next, on the bastion (DR producer continues the sequence):"
echo "  scripts/bastion-sync.sh -- \"cd python && source ../scripts/export-env.sh dr && uv run python produce_rides.py --interval 0.5 --start-seq $(( ${PRE_MAX:-0} + 1 ))\""
echo
echo "Look at what DR holds now (the Cloud console cannot show private-cluster messages):"
echo "  scripts/peek-topic.sh dr rides_raw --stats"
echo "  scripts/peek-topic.sh dr rides_raw --last 5      # compare its seq with the producer high-water: $PRE_MAX"
echo
echo "Loss assessment: see README section 'Measure RPO and sequence loss'"
