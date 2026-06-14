#!/usr/bin/env bash
# Embed wiki markdown into pgvector (kma_wiki) inside the running km-agent container.
#
# Requires: stack up (./assistants/start_km_agent.sh --no-mkdocs), Postgres, wiki under context/wiki/
# Uses in-container fastembed (KMA_EMBED_PROVIDER=fastembed); no LLM or OMLX needed for indexing.
#
# Usage (from flink-studies repo root):
#   ./assistants/index_wiki.sh
#   ./assistants/index_wiki.sh --dry-run
#   ./assistants/index_wiki.sh --recreate

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KMA_STACK_DIR="${SCRIPT_DIR}/km-agent"
COMPOSE_FILE="${KMA_STACK_DIR}/compose.yaml"

die() {
  echo "index_wiki.sh: $*" >&2
  exit 1
}

[[ -f "${COMPOSE_FILE}" ]] || die "Missing ${COMPOSE_FILE}"
command -v docker >/dev/null 2>&1 || die "Docker CLI not found."

if ! docker compose -f "${COMPOSE_FILE}" --project-directory "${KMA_STACK_DIR}" ps --status running --services 2>/dev/null | grep -qx km-agent; then
  die "km-agent container is not running. Start with: ./assistants/start_km_agent.sh --no-mkdocs"
fi

echo "index_wiki.sh: embedding wiki under ${KMA_STACK_DIR}/context/wiki into kma_wiki..."
docker compose -f "${COMPOSE_FILE}" --project-directory "${KMA_STACK_DIR}" exec -T km-agent \
  /app/.venv/bin/python /app/scripts/index_wiki.py --context /app/context "$@"
