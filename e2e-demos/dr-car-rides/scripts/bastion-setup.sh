#!/usr/bin/env bash
# Runs ON THE BASTION (as root, e.g. through `aws ssm send-command`): install the tools the
# DR-side steps need. Idempotent. Binaries go to /usr/local/bin, the workspace to
# /opt/dr-car-rides. No secret is handled here; secrets arrive via scripts/pull-outputs.sh.
#
# Installs: git (dbt refuses to start without it), terraform (checksum verified), uv,
# Python 3.12, confluent CLI.
set -euo pipefail

TF_VERSION="${TF_VERSION:-1.16.3}"
WORKDIR="${WORKDIR:-/opt/dr-car-rides}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$WORKDIR"
chmod 755 "$WORKDIR"

# Amazon Linux 2023 package; dnf reaches its repositories through the NAT gateway.
if ! command -v git >/dev/null; then
  dnf install -y git >/dev/null
fi
git --version

if ! command -v terraform >/dev/null || ! terraform version | head -1 | grep -q "v$TF_VERSION"; then
  base="https://releases.hashicorp.com/terraform/${TF_VERSION}"
  zip="terraform_${TF_VERSION}_linux_amd64.zip"
  curl -fsSL --max-time 120 -o "$TMP/$zip" "$base/$zip"
  curl -fsSL --max-time 60 -o "$TMP/SHA256SUMS" "$base/terraform_${TF_VERSION}_SHA256SUMS"
  (cd "$TMP" && grep " $zip\$" SHA256SUMS | sha256sum -c -)
  unzip -qo "$TMP/$zip" terraform -d /usr/local/bin
  chmod 755 /usr/local/bin/terraform
fi
terraform version | head -1

if ! command -v uv >/dev/null; then
  url="https://github.com/astral-sh/uv/releases/latest/download/uv-x86_64-unknown-linux-gnu.tar.gz"
  curl -fsSL --max-time 120 -o "$TMP/uv.tar.gz" "$url"
  curl -fsSL --max-time 60 -o "$TMP/uv.tar.gz.sha256" "$url.sha256"
  (cd "$TMP" && sed 's#  .*#  uv.tar.gz#' uv.tar.gz.sha256 | sha256sum -c -)
  tar -xzf "$TMP/uv.tar.gz" -C "$TMP"
  install -m 755 "$TMP"/uv-x86_64-unknown-linux-gnu/uv "$TMP"/uv-x86_64-unknown-linux-gnu/uvx /usr/local/bin/
fi
uv --version

if ! command -v confluent >/dev/null; then
  url="https://packages.confluent.io/confluent-cli/archives/latest/confluent_linux_amd64.tar.gz"
  curl -fsSL --max-time 120 -o "$TMP/confluent.tar.gz" "$url"
  tar -xzf "$TMP/confluent.tar.gz" -C "$TMP"
  install -m 755 "$TMP"/confluent/confluent /usr/local/bin/confluent
fi
confluent version | head -1

# Python 3.12 for the DR-side Python tools (producer, peek_topic, assess_loss).
HOME=/root uv python install 3.12 >/dev/null
echo "python 3.12 ready"
