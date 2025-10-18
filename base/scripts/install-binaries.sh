#!/usr/bin/env bash
set -euo pipefail

# Central installer for standalone CLI binaries.
# Variables expected (typically passed as build ARG -> ENV):
#   TARGETARCH, YQ_VERSION(+_SHA256), SYFT_VERSION(+_TARBALL_SHA256), GRYPE_VERSION(+_TARBALL_SHA256),
#   COSIGN_VERSION(+_SHA256), ORAS_VERSION(+_TARBALL_SHA256), LYCHEE_VERSION(+_TARBALL_SHA256),
#   TRIVY_VERSION(+_TARBALL_SHA256)
# Controls:
#   ENFORCE_CHECKSUMS=1 to fail if checksum variable empty.

log() { printf '[install-binaries] %s\n' "$*"; }
warn() { printf '[install-binaries][warn] %s\n' "$*" >&2; }
fail() { printf '[install-binaries][error] %s\n' "$*" >&2; exit 1; }

: "${TARGETARCH:=amd64}"
: "${ENFORCE_CHECKSUMS:=0}"
: "${SKIP_TOOLS:=0}"

need_checksum_or_skip() {
  local name=$1 var=$2
  local val="${!var:-}" || true
  if [[ -z $val ]]; then
    if [[ $ENFORCE_CHECKSUMS == 1 ]]; then
      fail "Checksum required for $name ($var) but not provided"
    else
      warn "Skipping checksum for $name (var $var empty)"
    fi
  fi
}

verify_checksum() { # expected file
  local expected=$1 file=$2
  [[ -z $expected ]] && return 0
  echo "${expected}  ${file}" | sha256sum -c -
}

download() { curl -fSL --retry 5 --retry-delay 3 --retry-connrefused -o "$2" "$1"; }

install_yq() {
  : "${YQ_VERSION:?YQ_VERSION required}"
  local url="https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/yq_linux_${TARGETARCH}"
  need_checksum_or_skip yq YQ_SHA256
  download "$url" /usr/local/bin/yq
  verify_checksum "${YQ_SHA256:-}" /usr/local/bin/yq || [[ -z ${YQ_SHA256:-} ]] || fail "yq checksum mismatch"
  chmod +x /usr/local/bin/yq
  yq --version
}

install_archive_tool() { # name version template checksum_var binary
  local name=$1 version=$2 template=$3 checksum_var=$4 bin=$5
  local checksum="${!checksum_var:-}" || true
  local file="/tmp/${name}.tgz"
  local url
  url=$(printf '%s' "$template" | sed "s/{{VERSION}}/${version#v}/; s/{{V}}/${version}/; s/{{ARCH}}/${TARGETARCH}/")
  need_checksum_or_skip "$name" "$checksum_var"
  download "$url" "$file"
  verify_checksum "$checksum" "$file" || [[ -z $checksum ]] || fail "$name checksum mismatch"
  tar -xzf "$file" -C /usr/local/bin "$bin" || fail "Extract $name failed"
  rm -f "$file"
  command -v "$bin" >/dev/null || fail "$name binary missing after install"
  "$bin" version || true
}

install_syft() { : "${SYFT_VERSION:?}"; install_archive_tool syft "$SYFT_VERSION" "https://github.com/anchore/syft/releases/download/${SYFT_VERSION}/syft_{{VERSION}}_linux_{{ARCH}}.tar.gz" SYFT_TARBALL_SHA256 syft; }
install_grype() { : "${GRYPE_VERSION:?}"; install_archive_tool grype "$GRYPE_VERSION" "https://github.com/anchore/grype/releases/download/${GRYPE_VERSION}/grype_{{VERSION}}_linux_{{ARCH}}.tar.gz" GRYPE_TARBALL_SHA256 grype; }
install_oras() { : "${ORAS_VERSION:?}"; install_archive_tool oras "$ORAS_VERSION" "https://github.com/oras-project/oras/releases/download/${ORAS_VERSION}/oras_{{VERSION}}_linux_{{ARCH}}.tar.gz" ORAS_TARBALL_SHA256 oras; }

# Trivy distribution switched to tar.gz releases with a binary 'trivy'
# Note: Trivy uses non-standard arch labels in asset names:
#   amd64 -> 64bit, arm64 -> ARM64
install_trivy() {
  : "${TRIVY_VERSION:?}"
  local orig_arch=${TARGETARCH}
  local trivy_arch
  case "${TARGETARCH}" in
    amd64) trivy_arch=64bit ;;
    arm64) trivy_arch=ARM64 ;;
    *) trivy_arch=64bit ;;
  esac
  # Temporarily override TARGETARCH for templating inside install_archive_tool
  TARGETARCH="${trivy_arch}"
  install_archive_tool trivy "${TRIVY_VERSION}" "https://github.com/aquasecurity/trivy/releases/download/${TRIVY_VERSION}/trivy_{{VERSION}}_Linux-{{ARCH}}.tar.gz" TRIVY_TARBALL_SHA256 trivy
  TARGETARCH="${orig_arch}"
}

install_cosign() {
  : "${COSIGN_VERSION:?}"
  need_checksum_or_skip cosign COSIGN_SHA256
  local url="https://github.com/sigstore/cosign/releases/download/${COSIGN_VERSION}/cosign-linux-${TARGETARCH}"
  download "$url" /usr/local/bin/cosign
  verify_checksum "${COSIGN_SHA256:-}" /usr/local/bin/cosign || [[ -z ${COSIGN_SHA256:-} ]] || fail "cosign checksum mismatch"
  chmod +x /usr/local/bin/cosign
  cosign version || true
}

install_lychee() {
  : "${LYCHEE_VERSION:?}"
  local arch
  case "$TARGETARCH" in
    amd64) arch=x86_64-unknown-linux-gnu ;;
    arm64) arch=aarch64-unknown-linux-gnu ;;
    *) arch=x86_64-unknown-linux-gnu ;;
  esac
  local tmp=/tmp/lychee
  mkdir -p "$tmp"; pushd "$tmp" >/dev/null
  local url1="https://github.com/lycheeverse/lychee/releases/download/${LYCHEE_VERSION}/lychee-${LYCHEE_VERSION}-${arch}.tar.gz"
  local url2="https://github.com/lycheeverse/lychee/releases/download/${LYCHEE_VERSION}/lychee-${arch}.tar.gz"
  need_checksum_or_skip lychee LYCHEE_TARBALL_SHA256
  if ! download "$url1" lychee.tgz; then download "$url2" lychee.tgz || fail "lychee download failed"; fi
  verify_checksum "${LYCHEE_TARBALL_SHA256:-}" lychee.tgz || [[ -z ${LYCHEE_TARBALL_SHA256:-} ]] || fail "lychee checksum mismatch"
  tar -xzf lychee.tgz
  install -m 0755 lychee /usr/local/bin/lychee
  popd >/dev/null
  rm -rf "$tmp"
  lychee --version || fail "lychee failed to run"
}

main() {
  if [[ "${SKIP_TOOLS}" == "1" ]]; then
    warn "SKIP_TOOLS=1 detected; skipping installation of standalone CLI binaries (yq, syft, grype, cosign, oras, lychee, trivy)"
    return 0
  fi
  install_yq
  install_syft
  install_grype
  install_cosign
  install_oras
  install_lychee
  install_trivy
  log "All binaries installed"
}

main "$@"
