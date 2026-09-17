#!/usr/bin/env bash
# Failback procedure including Schema Linking reverse and primary redeploy.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLINK_DIR="$SCRIPT_DIR/../flink-sql"

echo "=== Failback: DR → Primary ==="
echo "1) Stop producer writing to DR (Ctrl-C)."
echo
echo "2) Undeploy DR Flink DML statements:"
echo "   make -C $FLINK_DIR undeploy SITE=dr"
if command -v confluent >/dev/null 2>&1; then
  for name in flink-sql-dims-pipeline-rides-clean flink-sql-facts-pipeline-driver-stats; do
    confluent flink statement stop "$name" --cloud 2>/dev/null || true
  done
fi
echo
echo "3) Schema Linking failback sync:"
echo "   a. Set primary Schema Registry mode to IMPORT."
echo "   b. Create/start exporter DR → primary (subjects :*:) until caught up."
echo "   c. Pause DR → primary exporter; set primary SR back to READWRITE."
echo "   d. Set DR Schema Registry back to IMPORT and resume primary → DR exporter."
echo
echo "4) Recreate or sync mirror topics if mirrors were PROMOTED:"
echo "   (Refer to Confluent Cluster Link failback / mirror recreation docs)"
echo
echo "5) Redeploy Flink statements on Primary:"
echo "   make -C $FLINK_DIR deploy SITE=primary"
echo
echo "6) Retarget producer back to Primary:"
echo "   source $SCRIPT_DIR/export-env.sh primary"
echo "   cd $SCRIPT_DIR/../../python && uv run produce_rides.py --interval 0.5"
echo
echo "7) Point query engine (Athena) back at primary Glue DB / Tableflow."
echo
echo "Failback steps complete. Document measured RTO/RPO in your runbook."
