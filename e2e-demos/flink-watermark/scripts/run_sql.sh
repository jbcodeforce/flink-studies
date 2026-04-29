#!/usr/bin/env sh
# Run one SQL file inside the JobManager (streaming job: stop with Ctrl+C or cancel in the UI).
set -e
cd "$(dirname "$0")/.."
SQL_NAME="${1:?usage: run_sql.sh 01_baseline.sql|02_mitigation.sql}"
./scripts/wait_for_flink.sh
docker exec -i flink_wm_jobmanager ./bin/sql-client.sh embedded -f "/opt/flink-wm-sql/${SQL_NAME}"
