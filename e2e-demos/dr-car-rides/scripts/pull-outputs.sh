#!/usr/bin/env bash
# Runs ON THE BASTION: fetch iac-outputs.json from Parameter Store (written by
# scripts/push-outputs.sh on the laptop) using the instance role. File mode 600.
#
# Usage (on the bastion):  scripts/pull-outputs.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT="${IAC_OUTPUTS:-$SCRIPT_DIR/iac-outputs.json}"
REGION="${AWS_REGION:-us-east-1}"
NAME="${OUTPUTS_PARAMETER_NAME:-/dr-car-rides/iac-outputs}"

umask 077
aws ssm get-parameter --region "$REGION" --name "$NAME" --with-decryption \
  --query 'Parameter.Value' --output text >"$OUT"
jq -e . "$OUT" >/dev/null
echo "Wrote $OUT ($(wc -c <"$OUT" | tr -d ' ') bytes)" >&2
