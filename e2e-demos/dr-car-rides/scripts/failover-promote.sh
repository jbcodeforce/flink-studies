#!/usr/bin/env bash
# Convert the DR mirror topics into independent, writable topics through the Kafka REST API.
# RUNS ON THE DR BASTION: the DR cluster is private, so its REST endpoint only resolves inside
# the VPC. failover-soft.sh calls it through scripts/bastion-sync.sh.
#
# Usage (on the bastion, after scripts/pull-outputs.sh):
#   scripts/failover-promote.sh                    # planned: waits for lag 0, no data loss
#   scripts/failover-promote.sh --mode failover    # unplanned: cut over now, tail may be lost
#
# Promoting is one-way: the topics stop mirroring and accept producer writes. To go back,
# run scripts/failback.sh. Safe to re-run: mirrors already STOPPED are skipped.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODE="promote"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode) MODE="${2:-}"; shift 2 ;;
    *) echo "usage: failover-promote.sh [--mode promote|failover]" >&2; exit 2 ;;
  esac
done
[[ "$MODE" == "promote" || "$MODE" == "failover" ]] || { echo "--mode must be promote or failover" >&2; exit 2; }

# shellcheck disable=SC1091
source "$SCRIPT_DIR/export-env.sh" dr >/dev/null

# Only the source is mirrored; rides_clean / driver_stats are re-created by dbt on DR.
TOPICS=(rides_raw)
LINK="${CLUSTER_LINK_NAME:-dr-rides-primary-to-dr}"
BASE="$KAFKA_REST_ENDPOINT/kafka/v3/clusters/$KAFKA_CLUSTER_ID/links/$LINK/mirrors"

# Credentials go through a curl config on a pipe, not the command line.
kcurl() { curl -sS --max-time 60 -K <(printf 'user = "%s:%s"\n' "$KAFKA_API_KEY" "$KAFKA_API_SECRET") "$@"; }

echo "=== Mirror ${MODE}: ${TOPICS[*]}"
echo "cluster=$KAFKA_CLUSTER_ID link=$LINK"

# Idempotent: only POST the mirrors that are not STOPPED yet, so a re-run is safe.
todo=()
for t in "${TOPICS[@]}"; do
  info="$(kcurl "$BASE/$t")"
  st="$(jq -r '.mirror_status // empty' <<<"$info" 2>/dev/null || true)"
  case "$st" in
    STOPPED)
      echo "  $t: already STOPPED (writable), skipping" ;;
    "")
      echo "  $t: no mirror found on link $LINK: $(jq -r '.message // .' <<<"$info" 2>/dev/null || echo "$info")" >&2
      echo "  Nothing to promote. Check the link and that the topic was mirrored before the outage." >&2
      exit 1 ;;
    *)
      echo "  $t: mirror_status=$st, will ${MODE}"
      todo+=("$t") ;;
  esac
done

if (( ${#todo[@]} > 0 )); then
  body="$(printf '%s\n' "${todo[@]}" | jq -R . | jq -sc '{mirror_topic_names: .}')"
  resp="$(kcurl -X POST -H 'Content-Type: application/json' -d "$body" "${BASE}:${MODE}")"

  if ! jq -e '.data | length > 0' <<<"$resp" >/dev/null 2>&1; then
    echo "Unexpected response (no .data):" >&2
    jq -r '.message // .' <<<"$resp" >&2
    exit 1
  fi
  jq -r '.data[] | "  \(.mirror_topic_name): error_code=\(.error_code // 0) \(.error_message // "")"' <<<"$resp"
  # A topic that became STOPPED between the GET and the POST is a success; anything else fails the step.
  if jq -e '[.data[] | select((.error_code // 0) != 0)
             | select((.error_message // "") | test("already stopped"; "i") | not)] | length > 0' \
       <<<"$resp" >/dev/null; then
    echo "At least one mirror could not be ${MODE}d." >&2
    exit 1
  fi
fi

echo "Waiting for every mirror to reach STOPPED..."
deadline=$((SECONDS + 180))
while (( SECONDS < deadline )); do
  pending=0
  for t in "${TOPICS[@]}"; do
    st="$(kcurl "$BASE/$t" | jq -r '.mirror_status // "UNKNOWN"')"
    [[ "$st" == "STOPPED" ]] || pending=$((pending + 1))
  done
  if (( pending == 0 )); then
    echo "All mirrors STOPPED (writable) after ${SECONDS}s."
    exit 0
  fi
  sleep 3
done

echo "Timed out waiting for STOPPED:" >&2
for t in "${TOPICS[@]}"; do
  echo "  $t: $(kcurl "$BASE/$t" | jq -c '{status: .mirror_status, lag: ([.mirror_lags[]?.lag] | add)}')" >&2
done
exit 1
