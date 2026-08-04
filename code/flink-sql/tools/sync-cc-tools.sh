#!/usr/bin/env bash
# Vendor-copy cc_deploy and manifest from upstream cc-tools when source SHAs change.
# Fingerprint: cc-tools-sync.sha256 (paths relative to this tools directory).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST_ROOT="${SCRIPT_DIR}"
SRC_ROOT="${CC_TOOLS_SRC:-/Users/jerome/Documents/Code/migration-to-flink-skills/cc-tools/src}"
FINGERPRINT="${DEST_ROOT}/cc-tools-sync.sha256"
PACKAGES="cc_deploy manifest"

sha256_file() {
  local f="$1"
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$f" | awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$f" | awk '{print $1}'
  else
    echo "error: need shasum or sha256sum" >&2
    exit 1
  fi
}

recorded_hash() {
  local rel="$1"
  if [[ ! -f "${FINGERPRINT}" ]]; then
    return 0
  fi
  # Match "hash  relative/path" lines; print hash only
  awk -v p="${rel}" '$2 == p { print $1; exit }' "${FINGERPRINT}"
}

if [[ ! -d "${SRC_ROOT}" ]]; then
  echo "error: source root not found: ${SRC_ROOT}" >&2
  echo "Set CC_TOOLS_SRC to the cc-tools/src directory." >&2
  exit 1
fi

for pkg in ${PACKAGES}; do
  if [[ ! -d "${SRC_ROOT}/${pkg}" ]]; then
    echo "error: missing package directory: ${SRC_ROOT}/${pkg}" >&2
    exit 1
  fi
done

copied=0
skipped=0
tmp_fingerprint="$(mktemp)"
trap 'rm -f "${tmp_fingerprint}"' EXIT

# Collect source *.py paths sorted for stable fingerprint output
tmp_list="$(mktemp)"
trap 'rm -f "${tmp_fingerprint}" "${tmp_list}"' EXIT
for pkg in ${PACKAGES}; do
  find "${SRC_ROOT}/${pkg}" -type f -name '*.py' ! -path '*/__pycache__/*'
done | sort > "${tmp_list}"

while IFS= read -r src || [[ -n "${src}" ]]; do
  [[ -z "${src}" ]] && continue
  rel="${src#"${SRC_ROOT}/"}"
  src_hash="$(sha256_file "${src}")"
  old_hash="$(recorded_hash "${rel}")"

  if [[ -n "${old_hash}" && "${src_hash}" == "${old_hash}" ]]; then
    skipped=$((skipped + 1))
  else
    dest="${DEST_ROOT}/${rel}"
    mkdir -p "$(dirname "${dest}")"
    cp "${src}" "${dest}"
    echo "copied  ${rel}"
    copied=$((copied + 1))
  fi

  printf '%s  %s\n' "${src_hash}" "${rel}" >> "${tmp_fingerprint}"
done < "${tmp_list}"

sort -k2,2 "${tmp_fingerprint}" -o "${tmp_fingerprint}"
mv "${tmp_fingerprint}" "${FINGERPRINT}"
rm -f "${tmp_list}"
trap - EXIT

echo "sync done: ${copied} copied, ${skipped} skipped"
echo "fingerprint: ${FINGERPRINT}"
