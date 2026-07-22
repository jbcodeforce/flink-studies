#!/usr/bin/env bash
# Add km-agent raw YAML frontmatter to studies docs/ markdown.
#
# Usage (from studies repo):
#   ./assistants/km-agent/add_raw_frontmatter.sh
#   ./assistants/km-agent/add_raw_frontmatter.sh --check
#   ./assistants/km-agent/add_raw_frontmatter.sh --force

set -euo pipefail

STUDIES_KMA_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STUDIES_ROOT="$(cd "${STUDIES_KMA_DIR}/../.." && pwd)"
DOCS_DIR="${STUDIES_ROOT}/docs"
KMA_HOME_FILE="${STUDIES_KMA_DIR}/.kma-home"
ENV_FILE="${STUDIES_KMA_DIR}/.env"
CONTEXT_DIR="${STUDIES_KMA_DIR}/context"
STUDIES_LABEL="flink"

die() {
  echo "add_raw_frontmatter.sh: $*" >&2
  exit 1
}

if [[ ! -f "${KMA_HOME_FILE}" ]]; then
  die "missing ${KMA_HOME_FILE}; re-run km-agent/scripts/setup_studies.sh"
fi

KMA_HOME="$(tr -d '[:space:]' < "${KMA_HOME_FILE}")"
[[ -d "${KMA_HOME}" ]] || die "KMA_HOME not found: ${KMA_HOME}"
[[ -d "${DOCS_DIR}" ]] || die "docs directory not found: ${DOCS_DIR}"

command -v uv >/dev/null 2>&1 || die "uv not found; install uv"

if [[ -f "${ENV_FILE}" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "${ENV_FILE}"
  set +a
fi

CONTEXT_DIR="${KMA_CONTEXT_DIR:-${CONTEXT_DIR}}"

exec uv run --directory "${KMA_HOME}" --env-file "${ENV_FILE}" \
  python scripts/add_raw_frontmatter.py "${DOCS_DIR}" \
  --source "${STUDIES_LABEL}" \
  --context "${CONTEXT_DIR}" \
  --label "${STUDIES_LABEL}" \
  "$@"
