#!/usr/bin/env bash
# Smoke test: imports only (no Flink cluster required).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
exec "$ROOT/oss-flink/scripts/validate_env.sh"
