#!/usr/bin/env bash
# Start km-agent (Docker image) + MkDocs for flink-studies. No km-agent repo clone required.
#
# From the flink-studies repository root:
#   ./assistants/start_km_agent.sh              # Docker stack + MkDocs on :8003
#   ./assistants/start_km_agent.sh --no-mkdocs    # Docker stack only (logs until Ctrl+C)
#   ./assistants/start_km_agent.sh --pull         # docker compose pull before up
#   ./assistants/start_km_agent.sh --down         # stop containers and exit
#
# OMLX is external: run on this Mac or point KMA_LLM_BASE_URL at a remote host in
# assistants/km-agent/.env (see .env.example). This script probes OMLX but never starts it.
#
# Environment (assistants/km-agent/.env):
#   KMA_LLM_BASE_URL, KMA_EMBED_BASE_URL, KMA_LLM_MODEL_ID, KMA_EMBED_MODEL, ...
#   KMA_STOP_DOCKER_ON_EXIT=1  Stop compose on script exit (default: leave running)

set -euo pipefail

usage() {
  cat <<'EOF'
Start km-agent (Docker) and optionally MkDocs for flink-studies.

Usage:
  ./assistants/start_km_agent.sh [--no-mkdocs] [--pull] [--down] [-h|--help]

  (no flags)     docker compose up -d, probe OMLX, wait for AgentOS, mkdocs serve :8003
  --no-mkdocs    Docker stack only; follow km-agent logs until Ctrl+C
  --pull         docker compose pull before up
  --down         docker compose down and exit
  -h, --help     Show this help

Configure OMLX and models in assistants/km-agent/.env (copy from .env.example).
EOF
}

die() {
  echo "start_km_agent.sh: $*" >&2
  exit 1
}

have_cmd() {
  command -v "$1" >/dev/null 2>&1
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLINK_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
KMA_STACK_DIR="${SCRIPT_DIR}/km-agent"
COMPOSE_FILE="${KMA_STACK_DIR}/compose.yaml"
ENV_FILE="${KMA_STACK_DIR}/.env"
ENV_EXAMPLE="${KMA_STACK_DIR}/.env.example"

WITH_MKDOCS=1
DO_PULL=0
DO_DOWN=0

for arg in "$@"; do
  case "$arg" in
    --no-mkdocs) WITH_MKDOCS=0 ;;
    --pull) DO_PULL=1 ;;
    --down) DO_DOWN=1 ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "unknown option: $arg (try --help)"
      ;;
  esac
done

require_docker() {
  have_cmd docker || die "Docker CLI not found. Install Docker Desktop for Mac."
  docker compose version >/dev/null 2>&1 || die "'docker compose' not available."
  [[ -f "${COMPOSE_FILE}" ]] || die "Missing ${COMPOSE_FILE}"
}

ensure_env_file() {
  if [[ ! -f "${ENV_FILE}" ]]; then
    if [[ -f "${ENV_EXAMPLE}" ]]; then
      cp "${ENV_EXAMPLE}" "${ENV_FILE}"
      echo "start_km_agent.sh: created ${ENV_FILE} from .env.example — edit model IDs and OMLX URLs."
    else
      die "Missing ${ENV_FILE} and ${ENV_EXAMPLE}"
    fi
  fi
}

load_env_file() {
  ensure_env_file
  echo "start_km_agent.sh: loading ${ENV_FILE}..."
  set -a
  # shellcheck disable=SC1090
  source "${ENV_FILE}"
  set +a
}

ensure_context_dir() {
  local ctx="${KMA_CONTEXT_DIR:-./context}"
  if [[ "${ctx}" != /* ]]; then
    ctx="${KMA_STACK_DIR}/${ctx#./}"
  fi
  mkdir -p "${ctx}/raw" "${ctx}/wiki"
}

compose() {
  docker compose -f "${COMPOSE_FILE}" --project-directory "${KMA_STACK_DIR}" "$@"
}

compose_down_on_exit() {
  if [[ "${KMA_STOP_DOCKER_ON_EXIT:-0}" == "1" ]]; then
    echo "start_km_agent.sh: stopping Docker stack (KMA_STOP_DOCKER_ON_EXIT=1)..."
    compose down || true
  fi
}

probe_omlx() {
  have_cmd curl || die "curl not found (needed to probe OMLX)."
  local base="${KMA_LLM_BASE_URL:-http://host.docker.internal:7999/v1}"
  base="${base%/}"
  local models_url="${base}/models"
  local api_key="${KMA_LLM_API_KEY:-not-needed}"

  if curl -fsS -H "Authorization: Bearer ${api_key}" "${models_url}" >/dev/null 2>&1; then
    echo "OMLX is reachable at ${base}"
    return 0
  fi

  echo "WARN: OMLX is not reachable at ${models_url}" >&2
  echo "      Chat and embeddings will fail until OMLX responds." >&2
  echo "      Same Mac: start OMLX on the host (e.g. omlx serve --model-dir=\$HOME/.lmstudio/models)" >&2
  echo "      Remote: set KMA_LLM_BASE_URL and KMA_EMBED_BASE_URL in ${ENV_FILE}" >&2
  return 0
}

wait_for_agentos() {
  have_cmd curl || die "curl not found (needed to wait for AgentOS)."
  local port="${KMA_AGENT_OS_PORT:-8000}"
  local url="http://127.0.0.1:${port}/agents"
  local ready=0
  for _ in $(seq 1 60); do
    if curl -sf "${url}" >/dev/null 2>&1; then
      ready=1
      break
    fi
    sleep 0.5
  done
  if [[ "${ready}" -ne 1 ]]; then
    echo "WARN: timed out waiting for GET ${url}" >&2
    echo "      Check logs: docker compose -f ${COMPOSE_FILE} logs km-agent" >&2
    return 1
  fi
  echo "AgentOS ready: http://127.0.0.1:${port}"
  return 0
}

print_urls() {
  local port="${KMA_AGENT_OS_PORT:-8000}"
  echo "--- Services ---"
  echo "  Expert chat UI:  http://localhost:${port}"
  echo "  AgentOS API:     http://localhost:${port}/docs"
  if [[ "${WITH_MKDOCS}" == "1" ]]; then
    echo "  MkDocs:          http://localhost:8003"
  fi
  echo "----------------"
}

start_stack() {
  require_docker
  load_env_file
  ensure_context_dir

  if [[ "${DO_PULL}" == "1" ]]; then
    echo "Pulling images..."
    compose pull
  fi

  echo "Starting Docker stack (Postgres + km-agent)..."
  compose up -d

  probe_omlx
  wait_for_agentos || true
  print_urls
}

require_docker

if [[ "${DO_DOWN}" == "1" ]]; then
  load_env_file
  compose down
  echo "Docker stack stopped."
  exit 0
fi

trap compose_down_on_exit EXIT INT TERM

start_stack

if [[ "${WITH_MKDOCS}" == "1" ]]; then
  have_cmd mkdocs || die "mkdocs not found. Install MkDocs or use --no-mkdocs."
  echo "Starting MkDocs (foreground; Ctrl+C to stop)..."
  cd "${FLINK_ROOT}"
  exec mkdocs serve --dev-addr=localhost:8003
fi

echo "Following km-agent logs (Ctrl+C to stop)..."
compose logs -f km-agent
