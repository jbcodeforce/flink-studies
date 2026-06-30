#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

# shellcheck source=/dev/null
source "$(dirname "$0")/export_pythonpath.sh"
"$(dirname "$0")/validate_env.sh"

if ! curl -sf http://127.0.0.1:11434/api/tags >/dev/null 2>&1; then
  echo "Ollama does not appear to be running at http://127.0.0.1:11434" >&2
  echo "Start with: ollama serve" >&2
  exit 1
fi

echo "Running react_agent_example..."
exec uv run python -m flink_agents.examples.quickstart.react_agent_example
