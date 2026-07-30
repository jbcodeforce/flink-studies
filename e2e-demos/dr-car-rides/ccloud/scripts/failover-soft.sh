#!/usr/bin/env bash
# Soft failover: stop primary Flink DML, ensure schemas are on DR SR,
# deploy Flink+Tableflow on DR, retarget producer (incl. DR Schema Registry).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
FLINK_TF="$SCRIPT_DIR/../flink-sql/terraform"
DR_STATE="$SCRIPT_DIR/../flink-sql/dr-state"

echo "=== Soft failover: primary → DR ==="
echo "1) Stop the producer (Ctrl-C) if it is still writing to primary."
echo "2) Confirm Schema Linking caught up (exporter subjects on DR SR)."
echo "3) Record pre-failover max seq from the producer log or Flink UI."
echo

if command -v confluent >/dev/null 2>&1; then
  echo "Attempting to stop primary DML statements via Confluent CLI (best-effort)..."
  for name in dr-rides-primary-dml-rides-clean dr-rides-primary-dml-driver-stats; do
    confluent flink statement stop "$name" --cloud 2>/dev/null \
      || echo "  (skip/stop manually if needed: $name)"
  done
else
  echo "Confluent CLI not found — stop primary Flink DML statements in the Cloud UI:"
  echo "  dr-rides-primary-dml-rides-clean"
  echo "  dr-rides-primary-dml-driver-stats"
fi

echo
echo "4) Schema Registry failover (before producers/Flink write on DR):"
echo "   - Pause schema exporter primary→DR (Cloud UI or confluent schema-registry exporter pause)"
echo "   - Set DR SR mode from IMPORT → READWRITE so Flink/producers can register if needed"
echo "   Terraform steady-state keeps DR in IMPORT; change mode in UI for the demo window,"
echo "   or apply a targeted mode change. Schema IDs already replicated stay valid."
echo

echo "5) Deploying Flink statements + Tableflow on DR (separate TF state)..."
mkdir -p "$DR_STATE"
pushd "$FLINK_TF" >/dev/null
terraform init -input=false >/dev/null
terraform apply -auto-approve \
  -var="deploy_site=dr" \
  -var="statement_name_prefix=dr-rides-dr" \
  -state="$DR_STATE/terraform.tfstate"
popd >/dev/null

echo
echo "6) Retarget producer to DR (Kafka + Schema Registry):"
echo "   source $SCRIPT_DIR/export-env.sh dr"
echo "   cd $ROOT/python && uv run produce_rides.py --interval 0.5"
echo
echo "7) Assess loss:"
echo "   uv run assess_loss.py --producer-log /tmp/dr-car-rides-seq.log \\"
echo "     --pre-failover-max-seq <N> --post-mirror-max-seq <M>"
echo
echo "Catalog: point Athena at Glue DB from IaC output glue_database_dr"
echo "Soft failover complete."
