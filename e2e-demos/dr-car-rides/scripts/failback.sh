#!/usr/bin/env bash
# Failback DR -> primary after a soft failover. Run from the LAPTOP.
#
#   1. stop the DR Flink statements                       (public Flink API)
#   2. DR Schema Registry back to IMPORT, resume exporter (public Schema Registry)
#   3. resume the primary Flink statements                (public Flink API)
#   4. print what is NOT automated (data written on DR, mirror rebuild)
#
# Stop the DR producer first (Ctrl-C on the bastion).
#
# Data limitation: the DR cluster is private (PrivateLink), so it cannot be the source of a
# cluster link into the public primary cluster. Events produced on DR during the outage are
# NOT copied back. The demo keeps them on DR for inspection and re-creates the mirrors from
# the primary after failback (step 4 below).
#
# Usage: AWS_PROFILE=<profile> scripts/failback.sh [--yes]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATEMENTS=(dr-dims-rides-clean dr-facts-driver-stats)
ASSUME_YES=0
[[ "${1:-}" == "--yes" ]] && ASSUME_YES=1

for tool in jq curl; do
  command -v "$tool" >/dev/null || { echo "$tool is required" >&2; exit 1; }
done

with_site() { local site="$1"; shift; ( source "$SCRIPT_DIR/export-env.sh" "$site" >/dev/null; "$@" ); }
acurl() { local key="$1" secret="$2"; shift 2; curl -sS --max-time 60 -K <(printf 'user = "%s:%s"\n' "$key" "$secret") "$@"; }
step() { echo; echo "[$(date +%H:%M:%S)] $*"; }
statement_url() { echo "$FLINK_REST_ENDPOINT/sql/v1/organizations/$ORGANIZATION_ID/environments/$CONFLUENT_ENVIRONMENT_ID/statements/$1"; }

# $1 = true|false (stopped); waits for the matching phase.
set_statements_stopped() {
  local stopped="$1" name phase want
  [[ "$stopped" == "true" ]] && want="STOPPED" || want="RUNNING"
  for name in "${STATEMENTS[@]}"; do
    acurl "$FLINK_API_KEY" "$FLINK_API_SECRET" -X PATCH -H 'Content-Type: application/json' \
      -d "{\"spec\":{\"stopped\":$stopped}}" "$(statement_url "$name")" >/dev/null
  done
  for name in "${STATEMENTS[@]}"; do
    for _ in $(seq 1 45); do
      phase="$(acurl "$FLINK_API_KEY" "$FLINK_API_SECRET" "$(statement_url "$name")" | jq -r '.status.phase // "UNKNOWN"')"
      [[ "$phase" == "$want" || "$phase" == "COMPLETED" ]] && break
      sleep 2
    done
    echo "  $name: $phase"
    [[ "$phase" == "$want" || "$phase" == "COMPLETED" ]] || { echo "statement is not $want: $name" >&2; return 1; }
  done
}

dr_registry_import_and_resume() {
  acurl "$SCHEMA_REGISTRY_API_KEY" "$SCHEMA_REGISTRY_API_SECRET" -X PUT -H 'Content-Type: application/json' \
    -d '{"mode":"IMPORT"}' "$SCHEMA_REGISTRY_ENDPOINT/mode?force=true" | jq -r '"  DR registry mode: \(.mode // .message)"'
}
resume_exporter() {
  acurl "$SCHEMA_REGISTRY_API_KEY" "$SCHEMA_REGISTRY_API_SECRET" -X PUT \
    "$SCHEMA_REGISTRY_ENDPOINT/exporters/$SCHEMA_EXPORTER_NAME/resume" >/dev/null
  acurl "$SCHEMA_REGISTRY_API_KEY" "$SCHEMA_REGISTRY_API_SECRET" \
    "$SCHEMA_REGISTRY_ENDPOINT/exporters/$SCHEMA_EXPORTER_NAME/status" | jq -r '"  exporter state: \(.state)"'
}

echo "=== Failback: DR -> primary ==="
echo "Make sure the DR producer is STOPPED."
if [[ "$ASSUME_YES" -ne 1 ]]; then
  read -r -p "Proceed with the failback? [y/N] " answer
  [[ "$answer" == "y" || "$answer" == "Y" ]] || { echo "Aborted."; exit 1; }
fi

step "1/3 Stop the DR Flink statements"
with_site dr set_statements_stopped true

step "2/3 DR Schema Registry back to IMPORT, resume the primary -> DR exporter"
with_site dr dr_registry_import_and_resume
with_site primary resume_exporter

step "3/3 Resume the primary Flink statements"
with_site primary set_statements_stopped false

cat <<'EOF'

Not automated:
  - Events produced on DR during the outage stay on DR (private cluster, see header).
  - The DR rides_raw mirror is STOPPED (independent topic). To mirror from primary again, delete
    the DR topics (rides_raw, plus rides_clean and driver_stats that dbt created on DR) and
    re-create the mirror from the bastion:
        scripts/bastion-sync.sh -- "cd IaC/02-cluster-link && terraform destroy -auto-approve \
          && terraform apply -auto-approve"
    (the destroy removes the link and the stopped topics; apply recreates link + mirrors)
  - Record the measured RTO from failover-soft.sh and the RPO from assess_loss.py.
Failback steps complete.
EOF
