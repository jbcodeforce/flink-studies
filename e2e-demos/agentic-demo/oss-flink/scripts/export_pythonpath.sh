#!/usr/bin/env bash
# Source from demo root after: uv sync && source .venv/bin/activate
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

if [[ ! -d .venv ]]; then
  echo "Missing .venv — run: uv venv -p 3.11 && uv sync" >&2
  exit 1
fi

export PYTHONPATH="$(uv run python -c 'import sysconfig; print(sysconfig.get_paths()["purelib"])')"
echo "PYTHONPATH=$PYTHONPATH"
