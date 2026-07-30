#!/usr/bin/env bash
# Failback skeleton including Schema Linking reverse.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Failback (skeleton) ==="
echo "This is intentionally manual/low-automation for v1."
echo
echo "Suggested steps:"
echo "1) Stop producer writing to DR."
echo "2) Stop DR Flink DML (dr-rides-dr-dml-*)."
echo "3) Schema Linking failback:"
echo "   a. Set primary SR mode to IMPORT (force if needed)."
echo "   b. Create/start exporter DR → primary (subjects :*:) until caught up."
echo "   c. Pause DR→primary exporter; set primary SR to READWRITE."
echo "   d. Optionally set DR SR back to IMPORT and resume primary→DR exporter"
echo "      (return to steady-state Topology)."
echo "4) If mirrors were PROMOTED, reverse Cluster Link / recreate mirrors"
echo "   (see Confluent bidirectional link failback docs)."
echo "5) Resume or re-apply primary Flink statements (deploy_site=primary)."
echo "6) source $SCRIPT_DIR/export-env.sh primary && restart producer."
echo "7) Point Athena back at glue_database_primary after primary Tableflow catches up."
echo
echo "Document measured RTO/RPO in your runbook notes."
