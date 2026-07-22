#!/usr/bin/env bash
# Studies-hosted wrapper — delegates to km-agent starter-mac.sh with studies .env.
set -euo pipefail

STUDIES_KMA_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KMA_HOME_FILE="${STUDIES_KMA_DIR}/.kma-home"

if [[ ! -f "${KMA_HOME_FILE}" ]]; then
  echo "starter-mac.sh: missing ${KMA_HOME_FILE}; re-run km-agent/scripts/setup_studies.sh" >&2
  exit 1
fi

KMA_HOME="$(tr -d '[:space:]' < "${KMA_HOME_FILE}")"
if [[ ! -d "${KMA_HOME}" ]]; then
  echo "starter-mac.sh: KMA_HOME env variable not found: ${KMA_HOME}" >&2
  exit 1
fi

export KMA_ENV_FILE="${STUDIES_KMA_DIR}/.env"
exec "${KMA_HOME}/scripts/starter_mac.sh" "$@"
