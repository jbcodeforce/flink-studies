#!/usr/bin/env bash
# Start MkDocs local docs site. Optionally start km_agno AgentOS + chat UI when
# WITH_KM_AGNO_CHAT=1 (requires uv + npm deps under assistants/km_agno).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
ASSISTANT_DIR="${ROOT}/assistants/km_agno"
AGENT_LOG="${TMPDIR:-/tmp}/km-agno-agentos.log"

cleanup() {
  if [[ -n "${AGENT_PID:-}" ]] && kill -0 "$AGENT_PID" 2>/dev/null; then
    kill "$AGENT_PID" 2>/dev/null || true
  fi
  if [[ -n "${FRONT_PID:-}" ]] && kill -0 "$FRONT_PID" 2>/dev/null; then
    kill "$FRONT_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT INT TERM

# Wait until something listens on host:port (TCP). Avoids HTTP 401 from /agents when auth is on.
wait_for_port() {
  local host=$1
  local port=$2
  local max_attempts=${3:-45}
  local i=0
  while (( i < max_attempts )); do
    if bash -c "echo >/dev/tcp/${host}/${port}" 2>/dev/null; then
      return 0
    fi
    if [[ -n "${AGENT_PID:-}" ]] && ! kill -0 "${AGENT_PID}" 2>/dev/null; then
      return 2
    fi
    sleep 1
    (( i++ )) || true
  done
  return 1
}

echo "Starting local development environment..."
echo "  MkDocs site: http://localhost:8003"

if [[ "${WITH_KM_AGNO_CHAT:-}" == "1" ]]; then
  echo "  WITH_KM_AGNO_CHAT=1: AgentOS + chat UI (see docs/assistants/local-expert-chat.md)"

  if [[ ! -d "${ASSISTANT_DIR}" ]]; then
    echo "ERROR: Assistant directory not found: ${ASSISTANT_DIR}" >&2
    exit 1
  fi

  # Default top-bar link to MkDocs when unset; set VITE_STATIC_SITE_URL="" to hide the button.
  export VITE_STATIC_SITE_URL="${VITE_STATIC_SITE_URL-http://localhost:8003}"

  echo "  Syncing Python deps (uv sync)…"
  ( cd "${ASSISTANT_DIR}" && uv sync )

  : >"${AGENT_LOG}"
  echo "  AgentOS logs: ${AGENT_LOG}"
  # Default: no --reload. Uvicorn's reload watcher spawns a child that can pick up system Python
  # instead of uv's venv, causing ModuleNotFoundError: agno. Enable reload with KM_AGNO_UVICORN_RELOAD=1.
  RELOAD_FLAG=""
  if [[ "${KM_AGNO_UVICORN_RELOAD:-}" == "1" ]]; then
    RELOAD_FLAG="--reload"
    echo "  KM_AGNO_UVICORN_RELOAD=1: uvicorn --reload enabled"
  else
    echo "  AgentOS without --reload (use KM_AGNO_UVICORN_RELOAD=1 for auto-reload when debugging)"
  fi
  (
    cd "${ASSISTANT_DIR}"
    source .venv/bin/activate
    uv run python -m uvicorn km_agno.server:app ${RELOAD_FLAG} --host 127.0.0.1 --port 7777
  ) >>"${AGENT_LOG}" 2>&1 &
  AGENT_PID=$!

  echo "  Waiting for AgentOS on http://127.0.0.1:7777 …"
  if ! wait_for_port 127.0.0.1 7777 45; then
    if [[ -n "${AGENT_PID:-}" ]] && ! kill -0 "${AGENT_PID}" 2>/dev/null; then
      echo "ERROR: AgentOS process exited. Last lines from ${AGENT_LOG}:" >&2
      tail -40 "${AGENT_LOG}" >&2 || true
      exit 1
    fi
    echo "WARN: AgentOS did not listen on port 7777 in time. Last log lines:" >&2
    tail -40 "${AGENT_LOG}" >&2 || true
    echo "WARN: Continuing anyway (MkDocs will still start). Fix AgentOS manually from ${ASSISTANT_DIR}: uv run python -m uvicorn km_agno.server:app --host 127.0.0.1 --port 7777" >&2
  else
    echo "  AgentOS ready: http://127.0.0.1:7777/docs"
  fi

  (
    cd "${ASSISTANT_DIR}/frontend"
    exec npm run dev -- --host 127.0.0.1 --port 5174
  ) &
  FRONT_PID=$!
  sleep 1
  echo "  Expert chat UI: http://127.0.0.1:5174"
fi

cd "${ROOT}"
mkdocs serve --dev-addr=localhost:8003
