#!/usr/bin/env bash
# Look at the messages of a topic. The Confluent Cloud message viewer cannot be used on the
# private DR cluster ("your browser must have access to your cluster's private endpoints"),
# so DR is read from the bastion; primary is read directly from the laptop.
#
# Usage:
#   AWS_PROFILE=<profile> scripts/peek-topic.sh primary|dr <topic> [peek_topic.py options]
#   scripts/peek-topic.sh primary rides_raw --last 5
#   scripts/peek-topic.sh dr rides_clean --stats
#   scripts/peek-topic.sh dr rides_raw --partition 3 --last 20
#
# --follow works on primary only (SSM Run Command returns when the command ends).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SITE="${1:?usage: peek-topic.sh primary|dr <topic> [options]}"
TOPIC="${2:?usage: peek-topic.sh primary|dr <topic> [options]}"
shift 2

case "$SITE" in
  primary)
    source "$SCRIPT_DIR/export-env.sh" primary >/dev/null
    cd "$SCRIPT_DIR/../python" && uv run python peek_topic.py "$TOPIC" "$@"
    ;;
  dr)
    for a in "$@"; do
      [[ "$a" != "--follow" ]] || { echo "--follow is not supported through the bastion" >&2; exit 2; }
    done
    quoted="$(printf '%q ' "$TOPIC" "$@")"
    "$SCRIPT_DIR/bastion-sync.sh" -- "scripts/pull-outputs.sh && cd python && source ../scripts/export-env.sh dr >/dev/null && uv run python peek_topic.py $quoted 2>&1 | grep -v '^%'"
    ;;
  *) echo "site must be primary or dr" >&2; exit 2 ;;
esac
