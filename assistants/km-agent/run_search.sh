#!/usr/bin/env bash
# Research a query, compile raw into wiki, and lint.
#
# Usage (from studies repo):
#   ./assistants/km-agent/run_search.sh "your research question"
#   ./assistants/km-agent/run_search.sh "topic" --skip-research
#   ./assistants/km-agent/run_search.sh "topic" --src-file web_site_ref.json
#
# Requires Postgres + LLM; research needs KMA_PARALLEL_API_KEY (see starter_mac.sh --dev).

set -euo pipefail

STUDIES_KMA_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STUDIES_ROOT="$(cd "${STUDIES_KMA_DIR}/../.." && pwd)"
KMA_HOME_FILE="${STUDIES_KMA_DIR}/.kma-home"
ENV_FILE="${STUDIES_KMA_DIR}/.env"
CONTEXT_DIR="${STUDIES_ROOT}/docs/context"

die() {
  echo "run_search.sh: $*" >&2
  exit 1
}

if [[ ! -f "${KMA_HOME_FILE}" ]]; then
  die "missing ${KMA_HOME_FILE}; re-run km-agent/scripts/setup_studies.sh"
fi

KMA_HOME="$(tr -d '[:space:]' < "${KMA_HOME_FILE}")"
[[ -d "${KMA_HOME}" ]] || die "KMA_HOME not found: ${KMA_HOME}"

command -v uv >/dev/null 2>&1 || die "uv not found; install uv"

if [[ -f "${ENV_FILE}" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "${ENV_FILE}"
  set +a
fi

CONTEXT_DIR="${KMA_CONTEXT_DIR:-${CONTEXT_DIR}}"

exec uv run --directory "${KMA_HOME}" --env-file "${ENV_FILE}" \
  python scripts/run_search.py \
  --context "${CONTEXT_DIR}" \
  "$@"
