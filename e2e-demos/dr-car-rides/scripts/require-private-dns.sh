#!/usr/bin/env bash
# Fail early, with a clear message, when a DR private endpoint cannot be resolved, i.e. when a
# DR step runs OUTSIDE the DR VPC (the laptop).
#
# Usage: scripts/require-private-dns.sh [URL]    (default URL: $FLINK_ENDPOINT, set by
#                                                 `source scripts/export-env.sh dr`)
# Exit 0 = resolvable, exit 1 = not.
set -euo pipefail

url="${1:-${FLINK_ENDPOINT:?pass a URL or source scripts/export-env.sh dr first}}"
host="${url#*://}"
host="${host%%/*}"
host="${host%%:*}"

if python3 -c 'import socket,sys; socket.gethostbyname(sys.argv[1])' "$host" 2>/dev/null; then
  echo "private endpoint resolves: $host" >&2
else
  cat >&2 <<EOF
Cannot resolve $host from $(hostname).
The DR cluster is private (PrivateLink): this name only resolves inside the DR VPC.
Run this step ON THE BASTION (through SSM), for example:
  Layer 2 (cluster link):  AWS_PROFILE=<profile> scripts/apply-cluster-link.sh
  dbt on DR:               AWS_PROFILE=<profile> scripts/bastion-sync.sh -- "scripts/pull-outputs.sh && source scripts/export-env.sh dr >/dev/null && cd pipelines && make deploy SITE=dr"
EOF
  exit 1
fi
