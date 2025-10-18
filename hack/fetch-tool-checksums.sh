#!/usr/bin/env bash
set -euo pipefail
# fetch-tool-checksums.sh
# Fetch SHA256 checksums for yq, syft, grype, cosign, oras, lychee for specified versions.
# Usage: hack/fetch-tool-checksums.sh --yq 4.44.3 --syft v1.22.0 --grype v0.69.1 --cosign v2.6.0 --oras v1.2.2 --lychee v0.15.1
# Writes files to ci-checksums/<tool>/<version>/ and echoes export lines for .env consumption.
# Only linux amd64 + arm64 (where available) are considered.
# NOTE: Some upstreams provide a single multi-arch build (cosign) or only tarballs.

usage() {
  cat <<'EOF'
Usage: hack/fetch-tool-checksums.sh [--yq <ver>] [--syft <vX.Y.Z>] [--grype <vX.Y.Z>] [--cosign <vX.Y.Z>] [--oras <vX.Y.Z>] [--lychee <vX.Y.Z>] [--force]
EOF
}

FORCE=0
yq_ver=""; syft_ver=""; grype_ver=""; cosign_ver=""; oras_ver=""; lychee_ver=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --yq) yq_ver="$2"; shift 2;;
    --syft) syft_ver="$2"; shift 2;;
    --grype) grype_ver="$2"; shift 2;;
    --cosign) cosign_ver="$2"; shift 2;;
    --oras) oras_ver="$2"; shift 2;;
    --lychee) lychee_ver="$2"; shift 2;;
    --force) FORCE=1; shift;;
    -h|--help) usage; exit 0;;
    *) echo "Unknown arg: $1" >&2; usage; exit 2;;
  esac
done

root_dir="$(cd "$(dirname "$0")/.." && pwd)"
chk_root="${root_dir}/ci-checksums"
mkdir -p "$chk_root"

need_cmd() { command -v "$1" >/dev/null 2>&1 || { echo "Missing required tool: $1" >&2; exit 3; }; }
need_cmd curl
need_cmd grep
need_cmd awk

write_checksum_file() {
  local path="$1" hash="$2" filename="$3"
  if [[ -f "$path" && $FORCE -eq 0 ]]; then
    echo "Skip (exists): $path" >&2
    return 0
  fi
  echo "${hash}  ${filename}" > "$path"
  echo "Wrote: $path" >&2
}

export_line() { echo "export $1=$2"; }

# yq: checksums file lists <sha256>  yq_linux_<arch>
if [[ -n "$yq_ver" ]]; then
  dir="$chk_root/yq/${yq_ver}"; mkdir -p "$dir"
  sum_url="https://github.com/mikefarah/yq/releases/download/v${yq_ver}/checksums"
  tmp=$(mktemp); curl -fsSL "$sum_url" -o "$tmp"
  for arch in amd64 arm64; do
    file="yq_linux_${arch}"
    line=$(grep -E "^[0-9a-f]{64}  ${file}$" "$tmp" || true)
    if [[ -n "$line" ]]; then
      sha=${line%% *}
      write_checksum_file "${dir}/${file}.sha256" "$sha" "$file"
      [[ "$arch" == amd64 ]] && export_line YQ_SHA256_AMD64 "$sha" || export_line YQ_SHA256_ARM64 "$sha"
    fi
  done
  rm -f "$tmp"
fi

# syft & grype: tarball name pattern syft_<ver>_linux_<arch>.tar.gz
fetch_tgz_checksum() {
  local tool="$1" ver="$2" prefix="$3" ; shift 3 || true
  local dir="$chk_root/${tool}/${ver}"; mkdir -p "$dir"
  local base_url="https://github.com/anchore/${tool}/releases/download/${ver}"
  for arch in amd64 arm64; do
    file="${tool}_${ver#v}_linux_${arch}.tar.gz"
    sha_url="${base_url}/${file}.sha256"
    tmp=$(mktemp)
    if curl -fsSL "$sha_url" -o "$tmp"; then
      sha=$(tr -d ' \n\r' < "$tmp")
      write_checksum_file "${dir}/${file}.sha256" "$sha" "$file"
      case "$tool" in
        syft) [[ "$arch" == amd64 ]] && export_line SYFT_TARBALL_SHA256_AMD64 "$sha" || export_line SYFT_TARBALL_SHA256_ARM64 "$sha" ;;
        grype) [[ "$arch" == amd64 ]] && export_line GRYPE_TARBALL_SHA256_AMD64 "$sha" || export_line GRYPE_TARBALL_SHA256_ARM64 "$sha" ;;
      esac
    else
      echo "WARN: checksum not found for ${tool} ${ver} ${arch}" >&2
    fi
    rm -f "$tmp"
  done
}
[[ -n "$syft_ver" ]] && fetch_tgz_checksum syft "$syft_ver" syft
[[ -n "$grype_ver" ]] && fetch_tgz_checksum grype "$grype_ver" grype

# cosign: binary cosign-linux-<arch> plus .sig but we rely on .sha256 if published; else skip
if [[ -n "$cosign_ver" ]]; then
  dir="$chk_root/cosign/${cosign_ver}"; mkdir -p "$dir"
  base_url="https://github.com/sigstore/cosign/releases/download/${cosign_ver}"
  for arch in amd64 arm64; do
    file="cosign-linux-${arch}"
    sha_url="${base_url}/${file}.sha256"
    tmp=$(mktemp)
    if curl -fsSL "$sha_url" -o "$tmp"; then
      sha=$(tr -d ' \n\r' < "$tmp")
      write_checksum_file "${dir}/${file}.sha256" "$sha" "$file"
      [[ "$arch" == amd64 ]] && export_line COSIGN_SHA256_AMD64 "$sha" || export_line COSIGN_SHA256_ARM64 "$sha"
    else
      echo "WARN: cosign sha missing for arch ${arch}" >&2
    fi
    rm -f "$tmp"
  done
fi

# oras: oras_<ver#v>_linux_<arch>.tar.gz + .sha256
if [[ -n "$oras_ver" ]]; then
  dir="$chk_root/oras/${oras_ver}"; mkdir -p "$dir"
  base_url="https://github.com/oras-project/oras/releases/download/${oras_ver}"
  for arch in amd64 arm64; do
    file="oras_${oras_ver#v}_linux_${arch}.tar.gz"
    sha_url="${base_url}/${file}.sha256"
    tmp=$(mktemp)
    if curl -fsSL "$sha_url" -o "$tmp"; then
      sha=$(tr -d ' \n\r' < "$tmp")
      write_checksum_file "${dir}/${file}.sha256" "$sha" "$file"
      [[ "$arch" == amd64 ]] && export_line ORAS_TARBALL_SHA256_AMD64 "$sha" || export_line ORAS_TARBALL_SHA256_ARM64 "$sha"
    else
      echo "WARN: oras sha missing for arch ${arch}" >&2
    fi
    rm -f "$tmp"
  done
fi

# lychee: pattern differs; we attempted robust earlier logic so reuse same patterns as Dockerfile.
if [[ -n "$lychee_ver" ]]; then
  dir="$chk_root/lychee/${lychee_ver}"; mkdir -p "$dir"
  # Try both tag naming conventions
  for arch in x86_64 aarch64; do
    # multiple file name patterns tried; pick first working
    for tag in "${lychee_ver}" "lychee-${lychee_ver}"; do
      for file in "lychee-${lychee_ver}-${arch}-unknown-linux-gnu.tar.gz" "lychee-${arch}-unknown-linux-gnu.tar.gz"; do
        base_url="https://github.com/lycheeverse/lychee/releases/download/${tag}"
        # Upstream does not always publish .sha256, so we may have to download and compute (less ideal)
        sha_url="${base_url}/${file}.sha256"
        tmp=$(mktemp)
        if curl -fsSL "$sha_url" -o "$tmp"; then
          sha=$(tr -d ' \n\r' < "$tmp")
          write_checksum_file "${dir}/${file}.sha256" "$sha" "$file"
          case "$arch" in
            x86_64) export_line LYCHEE_TARBALL_SHA256_AMD64 "$sha" ;;
            aarch64) export_line LYCHEE_TARBALL_SHA256_ARM64 "$sha" ;;
          esac
          rm -f "$tmp"; break 3
        fi
        rm -f "$tmp"
      done
    done
  done
fi

echo "Done." >&2
