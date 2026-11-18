#!/usr/bin/env bash
# Inject (or undo) a primary-cluster outage. Run from the LAPTOP.
#
# Confluent Cloud offers no way to switch a Kafka cluster off, so the outage is simulated by
# deleting the CloudClusterAdmin role bindings of the two service accounts that talk to the
# primary Kafka cluster:
#   - the producer SA: used by produce_rides.py AND by the cluster link (its source credentials)
#   - the Flink SA:    used by the primary Flink statements
# From then on the producer gets authorization errors, the DR mirrors stop receiving data and
# the primary Flink statements fail. That is what DR sees in a real source-side outage.
# Limits: it is an authorization failure, not a network partition, and Schema Registry and the
# Flink control plane stay reachable.
#
# Nothing is destroyed. The role bindings are Terraform-managed (IaC/00-primary-flink), so
# --restore recreates exactly those two with a targeted `terraform apply`.
#
# Usage:
#   export CONFLUENT_CLOUD_API_KEY=... CONFLUENT_CLOUD_API_SECRET=...
#   scripts/simulate-primary-outage.sh [--yes]        # inject
#   scripts/simulate-primary-outage.sh --restore      # undo (before failback)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
L0_DIR="$(cd "$SCRIPT_DIR/../IaC/00-primary-flink" && pwd)"
BINDINGS=(dr_producer_cluster_admin dr_flink_cluster_admin)
ACTION="inject"
ASSUME_YES=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --restore) ACTION="restore"; shift ;;
    --yes) ASSUME_YES=1; shift ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done

for tool in jq curl terraform; do
  command -v "$tool" >/dev/null || { echo "$tool is required" >&2; exit 1; }
done
: "${CONFLUENT_CLOUD_API_KEY:?export CONFLUENT_CLOUD_API_KEY / CONFLUENT_CLOUD_API_SECRET (org-level keys)}"
: "${CONFLUENT_CLOUD_API_SECRET:?export CONFLUENT_CLOUD_API_KEY / CONFLUENT_CLOUD_API_SECRET (org-level keys)}"

step() { echo; echo "[$(date +%H:%M:%S)] $*"; }

# Credentials go through a curl config on a pipe, never the command line.
ccurl() { curl -sS --max-time 30 -K <(printf 'user = "%s:%s"\n' "$CONFLUENT_CLOUD_API_KEY" "$CONFLUENT_CLOUD_API_SECRET") "$@"; }

if [[ "$ACTION" == "inject" ]]; then
  [[ -s "$L0_DIR/terraform.tfstate" ]] || { echo "No Layer 0 state in $L0_DIR" >&2; exit 1; }
  # Producer and Flink can be running; the producer should be running to make the demo useful.
  echo "=== Simulate PRIMARY outage: delete role bindings ${BINDINGS[*]}"
  echo "Start produce_rides.py on primary first, so there is traffic in flight."
  if [[ "$ASSUME_YES" -ne 1 ]]; then
    read -r -p "Inject the outage now? [y/N] " answer
    [[ "$answer" == "y" || "$answer" == "Y" ]] || { echo "Aborted."; exit 1; }
  fi

  step "Record the producer high-water just before the outage"
  SEQ_LOG="${SEQ_LOG:-/tmp/dr-car-rides-seq.log}"
  if [[ -s "$SEQ_LOG" ]]; then
    echo "  last acknowledged seq before injection: $(jq -s 'map(.seq) | max' "$SEQ_LOG")  (log: $SEQ_LOG)"
  else
    echo "  no seq log at $SEQ_LOG"
  fi

  step "Delete the role bindings"
  for name in "${BINDINGS[@]}"; do
    id="$(jq -r --arg n "$name" '.resources[] | select(.type=="confluent_role_binding" and .name==$n) | .instances[0].attributes.id' "$L0_DIR/terraform.tfstate")"
    [[ -n "$id" ]] || { echo "  $name: not found in state" >&2; exit 1; }
    code="$(ccurl -o /dev/null -w '%{http_code}' -X DELETE "https://api.confluent.cloud/iam/v2/role-bindings/$id")"
    case "$code" in
      204|200) echo "  $name ($id): deleted" ;;
      404) echo "  $name ($id): already gone" ;;
      *) echo "  $name ($id): unexpected HTTP $code" >&2; exit 1 ;;
    esac
  done
  echo "  Wait about a minute for RBAC to propagate. Then expect in the producer terminal:"
  echo "  'DELIVERY FAILED ... TOPIC_AUTHORIZATION_FAILED'. The DR mirrors stop advancing"
  echo "  (scripts/peek-topic.sh dr rides_raw --stats)."
  echo
  echo "Next: scripts/failover-hard.sh"
else
  echo "=== Restore the primary: recreate role bindings ${BINDINGS[*]}"
  targets=()
  for name in "${BINDINGS[@]}"; do targets+=("-target=confluent_role_binding.$name"); done
  # The Confluent provider refuses to run when Kafka/SR/Flink variables are also exported.
  while read -r v; do unset "$v"; done < <(compgen -e | grep -E '^(KAFKA_|SCHEMA_REGISTRY_|FLINK_)' || true)
  step "terraform apply (targeted)"
  terraform -chdir="$L0_DIR" apply -auto-approve "${targets[@]}"
  echo
  echo "Primary access restored. Next: scripts/failback.sh"
fi
