#!/usr/bin/env bash
# Merge `terraform output -json` of every applied IaC layer into iac-outputs.json,
# the file read by export-env.sh. Layers without state yet are skipped.
#
# Usage: scripts/generate-outputs.sh
# Output: scripts/iac-outputs.json (gitignored; contains API keys and secrets)
#
# Run it again after each layer is applied. On the bastion, copy the L0/L1 state
# files first (see README), then run it there.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IAC_DIR="$(cd "$SCRIPT_DIR/../IaC" && pwd)"
OUT="${IAC_OUTPUTS:-$SCRIPT_DIR/iac-outputs.json}"

command -v terraform >/dev/null || { echo "terraform is required" >&2; exit 1; }
command -v jq >/dev/null || { echo "jq is required" >&2; exit 1; }

merged='{}'
found=()
for layer in "$IAC_DIR"/0[0-9]-*/; do
  name="$(basename "$layer")"
  if [[ ! -s "$layer/terraform.tfstate" ]]; then
    echo "skip   $name (no state)" >&2
    continue
  fi
  json="$(cd "$layer" && terraform output -json 2>/dev/null || true)"
  if [[ -z "$json" || "$json" == "{}" ]]; then
    echo "skip   $name (no outputs)" >&2
    continue
  fi
  merged="$(jq -s '.[0] * .[1]' <(echo "$merged") <(echo "$json"))"
  found+=("$name")
  echo "merged $name" >&2
done

if [[ ${#found[@]} -eq 0 ]]; then
  echo "No applied layer found under $IAC_DIR" >&2
  exit 1
fi

umask 077
echo "$merged" >"$OUT"
echo "Wrote $OUT (layers: ${found[*]})" >&2
