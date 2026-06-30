#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

# shellcheck source=/dev/null
source "$(dirname "$0")/export_pythonpath.sh"

uv run python -c "import flink_agents, pyflink; print('imports ok')"

if [[ -z "${PYTHONPATH:-}" ]]; then
  echo "PYTHONPATH is not set" >&2
  exit 1
fi

echo "validate_env: PASS"
