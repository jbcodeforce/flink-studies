#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

# shellcheck source=/dev/null
source "$(dirname "$0")/export_pythonpath.sh"
"$(dirname "$0")/validate_env.sh"

echo "Running workflow_single_agent_example..."
exec uv run python -m flink_agents.examples.quickstart.workflow_single_agent_example
