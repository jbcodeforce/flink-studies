#!/usr/bin/env bash
# Hard (unplanned) failover primary -> DR, for when the primary is DOWN. Run from the LAPTOP;
# only the DR Kafka REST step goes through the bastion (the DR cluster is private).
#
# Differences from failover-soft.sh, which needs a healthy primary:
#   - nothing on primary is required: stopping Flink and pausing the schema exporter are
#     best-effort and their failure is tolerated;
#   - schema ids cannot be compared with primary, so DR is only checked for the subjects;
#   - mirrors are cut over with `failover-promote.sh --mode failover` (no wait for lag 0),
#     so the unreplicated tail is LOST;
#   - the loss is measured at the end: acknowledged producer high-water (seq log) against the
#     max seq that DR holds.
#
#   1. stop primary Flink + pause the exporter  (laptop, best effort)
#   2. check subjects on DR, DR registry -> READWRITE (laptop, public Schema Registry)
#   3. failover the rides_raw mirror topic       (bastion, DR Kafka REST over PrivateLink)
#   4. deploy the dbt models on DR               (bastion, private Flink endpoint)
#   5. measure the loss                          (DR max seq from the bastion, assess_loss.py)
#
# To inject the outage first: scripts/simulate-primary-outage.sh
#
# Usage:
#   AWS_PROFILE=<profile> scripts/failover-hard.sh [--yes] [--seq-log FILE] [--skip-deploy]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SEQ_LOG="${SEQ_LOG:-/tmp/dr-car-rides-seq.log}"
STATEMENTS=(dr-dims-rides-clean dr-facts-driver-stats)
SUBJECTS=(rides_raw-key rides_raw-value)   # the only exported subjects; dbt registers the others on DR
ASSUME_YES=0
SKIP_DEPLOY=0
CURL_MAX_TIME=15   # primary may hang: do not wait the default 60s per call

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

with_site() { local site="$1"; shift; ( source "$SCRIPT_DIR/export-env.sh" "$site" >/dev/null; "$@" ); }
acurl() { local key="$1" secret="$2"; shift 2; curl -sS --max-time "$CURL_MAX_TIME" -K <(printf 'user = "%s:%s"\n' "$key" "$secret") "$@"; }
step() { echo; echo "[$(date +%H:%M:%S)] $*"; }

statement_url() { echo "$FLINK_REST_ENDPOINT/sql/v1/organizations/$ORGANIZATION_ID/environments/$CONFLUENT_ENVIRONMENT_ID/statements/$1"; }

# Best effort: a failed or unreachable primary must not block the failover.
stop_primary_statements() {
  local name phase
  for name in "${STATEMENTS[@]}"; do
    acurl "$FLINK_API_KEY" "$FLINK_API_SECRET" -X PATCH -H 'Content-Type: application/json' \
      -d '{"spec":{"stopped":true}}' "$(statement_url "$name")" >/dev/null 2>&1 || true
    phase="$(acurl "$FLINK_API_KEY" "$FLINK_API_SECRET" "$(statement_url "$name")" 2>/dev/null | jq -r '.status.phase // "UNKNOWN"' 2>/dev/null || echo UNREACHABLE)"
    echo "  $name: stop requested, phase now $phase"
  done
}

pause_exporter() {
  acurl "$SCHEMA_REGISTRY_API_KEY" "$SCHEMA_REGISTRY_API_SECRET" -X PUT \
    "$SCHEMA_REGISTRY_ENDPOINT/exporters/$SCHEMA_EXPORTER_NAME/pause" >/dev/null 2>&1 || true
  acurl "$SCHEMA_REGISTRY_API_KEY" "$SCHEMA_REGISTRY_API_SECRET" \
    "$SCHEMA_REGISTRY_ENDPOINT/exporters/$SCHEMA_EXPORTER_NAME/status" 2>/dev/null | jq -r '"  exporter state: \(.state)"' 2>/dev/null \
    || echo "  exporter: primary Schema Registry unreachable, not paused"
}

dr_subjects() {
  local s id missing=0
  for s in "${SUBJECTS[@]}"; do
    id="$(acurl "$SCHEMA_REGISTRY_API_KEY" "$SCHEMA_REGISTRY_API_SECRET" "$SCHEMA_REGISTRY_ENDPOINT/subjects/$s/versions/latest" | jq -r '"\(.id)/\(.version)"')"
    echo "  $s id/version=$id"
    [[ "$id" != "null/null" ]] || missing=1
  done
  [[ "$missing" -eq 0 ]] || { echo "DR is missing subjects: the exporter had not copied them" >&2; return 1; }
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

echo "=== Hard failover: primary -> DR (primary assumed DOWN) ==="
if [[ -s "$SEQ_LOG" ]]; then
  PRE_MAX="$(jq -s 'map(.seq) | max' "$SEQ_LOG")"
  echo "Producer high-water seq acknowledged by primary (from $SEQ_LOG): $PRE_MAX"
else
  PRE_MAX=""
  echo "No seq log at $SEQ_LOG: the loss cannot be measured."
fi
echo "The records after the last mirrored offset are NOT recovered."
if [[ "$ASSUME_YES" -ne 1 ]]; then
  read -r -p "Proceed with the hard failover? [y/N] " answer
  [[ "$answer" == "y" || "$answer" == "Y" ]] || { echo "Aborted."; exit 1; }
fi

T0=$SECONDS

step "1/5 Primary: stop Flink statements, pause the schema exporter (best effort)"
with_site primary stop_primary_statements || true
with_site primary pause_exporter || true

step "2/5 DR Schema Registry: check the subjects, set READWRITE"
with_site dr dr_subjects
with_site dr dr_registry_readwrite

step "3/5 Fail over the mirror topics (on the bastion, mode=failover)"
"$SCRIPT_DIR/bastion-sync.sh" -- "scripts/pull-outputs.sh && scripts/failover-promote.sh --mode failover"
RTO_KAFKA=$((SECONDS - T0))

if [[ "$SKIP_DEPLOY" -eq 1 ]]; then
  step "4/5 dbt deploy on DR skipped (--skip-deploy)"
else
  step "4/5 Deploy the dbt models on DR (on the bastion, private Flink endpoint)"
  deploy_dr
fi
RTO=$((SECONDS - T0))

step "5/5 Measure the loss"
DR_MAX="$("$SCRIPT_DIR/peek-topic.sh" dr rides_raw --last 60 | grep '^{' | jq -s 'map(.value.seq) | max' || true)"
if [[ -n "$DR_MAX" && "$DR_MAX" != "null" ]]; then
  echo "  max seq held by DR rides_raw: $DR_MAX"
  if [[ -n "$PRE_MAX" ]]; then
    ( cd "$ROOT/python" && uv run python assess_loss.py --producer-log "$SEQ_LOG" \
        --pre-failover-max-seq "$PRE_MAX" --post-mirror-max-seq "$DR_MAX" )
  fi
else
  echo "  could not read a seq from DR rides_raw. Run: scripts/peek-topic.sh dr rides_raw --last 20"
fi

echo
echo "Done. Kafka cut over after ${RTO_KAFKA}s, DR statements submitted after ${RTO}s (RTO)."
echo
echo "DR producer continues the sequence (the skipped seq range is the loss):"
echo "  scripts/bastion-sync.sh -- \"cd python && source ../scripts/export-env.sh dr && uv run python produce_rides.py --interval 0.5 --start-seq $(( ${PRE_MAX:-0} + 1 ))\""
echo
echo "Optional, to rerun the scenario: scripts/simulate-primary-outage.sh --restore, then scripts/cleanup-dr.sh"
