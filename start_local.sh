#!/usr/bin/env bash
# Start MkDocs local docs site. Optionally start km_agno AgentOS + chat UI when
# WITH_KM_AGNO_CHAT=1 (requires uv + npm deps under assistants/km_agno).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
ASSISTANT_DIR="${ROOT}/assistants/km_agno"

cleanup() {
  if [[ -n "${AGENT_PID:-}" ]] && kill -0 "$AGENT_PID" 2>/dev/null; then
    kill "$AGENT_PID" 2>/dev/null || true
  fi
  if [[ -n "${FRONT_PID:-}" ]] && kill -0 "$FRONT_PID" 2>/dev/null; then
    kill "$FRONT_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT INT TERM

echo "Starting local development environment..."
echo "  MkDocs site: http://localhost:8003"

if [[ "${WITH_KM_AGNO_CHAT:-}" == "1" ]]; then
  echo "  WITH_KM_AGNO_CHAT=1: AgentOS + chat UI (see docs/assistants/local-expert-chat.md)"
  # Default top-bar link to MkDocs when unset; set VITE_STATIC_SITE_URL="" to hide the button.
  export VITE_STATIC_SITE_URL="${VITE_STATIC_SITE_URL-http://localhost:8003}"
  (
    cd "${ASSISTANT_DIR}"
    
    exec uv sync && uv run uvicorn km_agno.server:app --reload --host localhost --port 7777
  ) &
  AGENT_PID=$!
  (
    cd "${ASSISTANT_DIR}/frontend"
    exec npm run dev -- --host localhost --port 5174
  ) &
  FRONT_PID=$!
  sleep 2
  echo "  Expert chat UI: http://localhost:5174"
  echo "  AgentOS OpenAPI: http://localhost:7777/docs"
fi
cd $ROOT
mkdocs serve --dev-addr=localhost:8003
