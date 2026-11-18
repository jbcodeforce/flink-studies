#!/usr/bin/env bash
# Laptop -> bastion: publish iac-outputs.json as ONE SecureString parameter that the
# bastion's IAM role can read (IaC/01-dr-site/bastion.tf). Secrets never travel through
# SSM command history. The parameter is deleted by `scripts/push-outputs.sh --delete`.
#
# Usage:
#   AWS_PROFILE=<profile> scripts/push-outputs.sh            # create / update
#   AWS_PROFILE=<profile> scripts/push-outputs.sh --delete   # remove at teardown
#
# Re-run after every layer apply so the bastion sees the new outputs.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUTS="${IAC_OUTPUTS:-$SCRIPT_DIR/iac-outputs.json}"
REGION="${AWS_REGION:-us-east-1}"
NAME="${OUTPUTS_PARAMETER_NAME:-/dr-car-rides/iac-outputs}"

command -v aws >/dev/null || { echo "aws CLI is required" >&2; exit 1; }
command -v jq >/dev/null || { echo "jq is required" >&2; exit 1; }

if [[ "${1:-}" == "--delete" ]]; then
  aws ssm delete-parameter --region "$REGION" --name "$NAME"
  echo "Deleted $NAME" >&2
  exit 0
fi

[[ -f "$OUTPUTS" ]] || { echo "Missing $OUTPUTS - run scripts/generate-outputs.sh first" >&2; exit 1; }

# Compact JSON; the value is read from a file so it never appears in the process list.
tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT
chmod 600 "$tmp"
jq -c . "$OUTPUTS" >"$tmp"

aws ssm put-parameter --region "$REGION" --name "$NAME" --type SecureString \
  --tier Intelligent-Tiering --overwrite --value "file://$tmp" >/dev/null
echo "Pushed $(wc -c <"$tmp" | tr -d ' ') bytes to $NAME ($REGION)" >&2
