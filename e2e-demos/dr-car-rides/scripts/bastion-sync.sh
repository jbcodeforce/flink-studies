#!/usr/bin/env bash
# Laptop -> bastion: copy the NON-SECRET code the DR-side steps need (Layer 2, scripts, python)
# to /opt/dr-car-rides on the bastion through SSM Run Command, then optionally run a command.
# Secrets are never part of this archive; they travel via push-outputs.sh / pull-outputs.sh.
#
# Usage:
#   AWS_PROFILE=<profile> scripts/bastion-sync.sh                  # copy files only
#   AWS_PROFILE=<profile> scripts/bastion-sync.sh -- <command...>  # copy, then run as root
#                                                                  # in /opt/dr-car-rides
# Environment: BASTION_ID (default: from iac-outputs.json), AWS_REGION (default us-east-1),
#              BASTION_SYNC_LOCKS=1 also sends python/uv.lock (see the size note below)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEMO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUTS="${IAC_OUTPUTS:-$SCRIPT_DIR/iac-outputs.json}"
REGION="${AWS_REGION:-us-east-1}"
BASTION_ID="${BASTION_ID:-$(jq -r '.dr_bastion_instance_id.value' "$OUTPUTS")}"

REMOTE_CMD=""
if [[ "${1:-}" == "--" ]]; then
  shift
  REMOTE_CMD="$*"
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# SSM SendCommand accepts at most 97KB of parameters, and the archive travels base64-encoded
# inside them. The lock files do not fit: pipelines/uv.lock is ~220KB and python/uv.lock adds
# ~37KB compressed. So:
#   - pipelines/uv.lock is never sent: the bastion resolves dbt-confluent from
#     pipelines/pyproject.toml (PyPI over the NAT);
#   - python/uv.lock is sent only with BASTION_SYNC_LOCKS=1. tar never deletes, so the copy
#     from an earlier sync stays on the bastion. Set it once after changing python/uv.lock.
LOCK_ARGS=()
[[ "${BASTION_SYNC_LOCKS:-0}" == "1" && -f "$DEMO_DIR/python/uv.lock" ]] && LOCK_ARGS=(python/uv.lock)
(cd "$DEMO_DIR" && COPYFILE_DISABLE=1 tar czf "$tmp/code.tgz" \
  --exclude='.terraform' --exclude='.terraform.lock.hcl' --exclude='*.tfstate*' --exclude='*.tfvars*' \
  --exclude='iac-outputs.json' --exclude='__pycache__' --exclude='.venv' \
  --exclude='pipelines/target' --exclude='pipelines/logs' --exclude='pipelines/dbt_packages' \
  --exclude='pipelines/uv.lock' \
  IaC/02-cluster-link scripts pipelines python/produce_rides.py python/assess_loss.py python/peek_topic.py \
  python/pyproject.toml ${LOCK_ARGS[@]+"${LOCK_ARGS[@]}"})

b64="$(base64 <"$tmp/code.tgz" | tr -d '\n')"
if (( ${#b64} > 85000 )); then
  echo "Archive is ${#b64} bytes base64; SSM SendCommand allows 97KB in total. Exclude something in bastion-sync.sh." >&2
  exit 1
fi
cmds=(
  "set -euo pipefail"
  # SSM runs as root without a login profile: set what uv needs. Python 3.12 has a
  # prebuilt confluent-kafka wheel; newer interpreters would need a C compiler (absent).
  "export HOME=/root UV_CACHE_DIR=/opt/dr-car-rides/.uv-cache UV_PYTHON=3.12"
  "mkdir -p /opt/dr-car-rides && cd /opt/dr-car-rides"
  "echo '$b64' | base64 -d | tar xzf -"
  "chmod +x scripts/*.sh"
)
if [[ -n "$REMOTE_CMD" ]]; then
  cmds+=("cd /opt/dr-car-rides" "$REMOTE_CMD")
fi

jq -n --args '{commands: $ARGS.positional}' "${cmds[@]}" >"$tmp/params.json"

cid="$(aws ssm send-command --region "$REGION" --instance-ids "$BASTION_ID" \
  --document-name AWS-RunShellScript --comment "dr-car-rides sync" \
  --parameters "file://$tmp/params.json" --query 'Command.CommandId' --output text)"

for _ in $(seq 1 90); do
  status="$(aws ssm get-command-invocation --region "$REGION" --command-id "$cid" \
    --instance-id "$BASTION_ID" --query 'Status' --output text 2>/dev/null || echo Pending)"
  case "$status" in
    Success|Failed|Cancelled|TimedOut) break ;;
  esac
  sleep 4
done

aws ssm get-command-invocation --region "$REGION" --command-id "$cid" --instance-id "$BASTION_ID" \
  --query '[StandardOutputContent,StandardErrorContent]' --output text
echo "status: $status" >&2
[[ "$status" == "Success" ]]
