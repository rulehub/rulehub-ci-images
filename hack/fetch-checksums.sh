#!/usr/bin/env bash
set -euo pipefail

# fetch-checksums.sh
# Fetch and store SHA256 checksums for OPA and Kyverno releases used in CI images.
# Intent: run manually when bumping versions (or integrate later into an automated guard).

usage() {
  cat <<'EOF'
Usage: hack/fetch-checksums.sh [--opa <version>] [--kyverno <version>] [--force]

Downloads published SHA256 sums from upstream release pages (GitHub or official site)
and writes them under ci-checksums/.

Options:
  --opa <v>        OPA version (e.g. 1.8.0)
  --kyverno <v>    Kyverno CLI version (e.g. 1.15.1)
  --force          Overwrite existing checksum files
  -h, --help       Show this help

Exit codes:
  0 success | 2 usage | 3 fetch error
EOF
}

OPA_VERSION=""
KYVERNO_VERSION=""
FORCE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --opa) OPA_VERSION="$2"; shift 2;;
    --kyverno) KYVERNO_VERSION="$2"; shift 2;;
    --force) FORCE=1; shift;;
    -h|--help) usage; exit 0;;
    *) echo "Unknown arg: $1" >&2; usage; exit 2;;
  esac
done

if [[ -z "$OPA_VERSION$KYVERNO_VERSION" ]]; then
  echo "Nothing to do (specify --opa and/or --kyverno)." >&2
  exit 2
fi

root_dir="$(cd "$(dirname "$0")/.." && pwd)"
chk_root="${root_dir}/ci-checksums"
mkdir -p "$chk_root"

download() {
  local url="$1" dest="$2"
  curl -fSL --retry 5 --retry-delay 3 --retry-connrefused -o "$dest" "$url" || return 1
}

write_checksum_file() {
  local path="$1" hash="$2" filename="$3"
  if [[ -f "$path" && $FORCE -eq 0 ]]; then
    echo "Skip (exists): $path" >&2
    return 0
  fi
  echo "${hash}  ${filename}" > "$path"
  echo "Wrote: $path" >&2
}

# OPA (static binary) checksum is published on official site with .sha256 hash file
if [[ -n "$OPA_VERSION" ]]; then
  opa_dir="${chk_root}/opa/${OPA_VERSION}"
  mkdir -p "$opa_dir"
  # We rely on .sha256 published next to the binary (content is just the hash, not 'hash  filename')
  base_url="https://openpolicyagent.org/downloads/v${OPA_VERSION}"
  for arch in amd64; do
    file="opa_linux_${arch}_static"
    sha_url="${base_url}/${file}.sha256"
    tmp="$(mktemp)" || exit 3
    if ! download "$sha_url" "$tmp"; then
      echo "Failed to fetch OPA checksum: $sha_url" >&2
      exit 3
    fi
    hash=$(tr -d ' \n\r' < "$tmp")
    write_checksum_file "${opa_dir}/linux_${arch}_static.sha256" "$hash" "$file"
    rm -f "$tmp"
  done
fi

# Kyverno CLI: upstream release assets include a .tar.gz and a checksums.txt containing lines "<sha256>  <file>"
if [[ -n "$KYVERNO_VERSION" ]]; then
  kyverno_dir="${chk_root}/kyverno/${KYVERNO_VERSION}"
  mkdir -p "$kyverno_dir"
  checksums_url="https://github.com/kyverno/kyverno/releases/download/v${KYVERNO_VERSION}/checksums.txt"
  tmp_all="$(mktemp)" || exit 3
  if ! download "$checksums_url" "$tmp_all"; then
    echo "Failed to fetch Kyverno checksums list: $checksums_url" >&2
    exit 3
  fi
  # Extract needed file(s)
  for arch in x86_64; do
    target="kyverno-cli_v${KYVERNO_VERSION}_linux_${arch}.tar.gz"
    line=$(grep -E "[[:alnum:]]{64}  ${target}$" "$tmp_all" || true)
    if [[ -z "$line" ]]; then
      echo "Checksum line not found for $target" >&2
      exit 3
    fi
    hash="${line%% *}"
    write_checksum_file "${kyverno_dir}/${target}.sha256" "$hash" "$target"
  done
  rm -f "$tmp_all"
fi

echo "Done." >&2
