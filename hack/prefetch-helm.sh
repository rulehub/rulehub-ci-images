#!/usr/bin/env bash
set -euo pipefail

# Prefetch a Helm release tarball into charts/cache for offline/resilient builds.
# Usage: ./hack/prefetch-helm.sh [HELM_VERSION] [ARCH]
#  - HELM_VERSION: v3.15.3 (default matches Dockerfile ARG)
#  - ARCH: amd64|arm64 (default derived from uname -m)

HELM_VERSION="${1:-v3.15.3}"
ARCH_INPUT="${2:-}"

if [[ -z "${ARCH_INPUT}" ]]; then
  UNAME_ARCH="$(uname -m)"
  case "${UNAME_ARCH}" in
    x86_64) ARCH_INPUT="amd64" ;;
    aarch64|arm64) ARCH_INPUT="arm64" ;;
    *) echo "[prefetch-helm] Unsupported host arch: ${UNAME_ARCH}. Specify amd64|arm64 explicitly." >&2; exit 1 ;;
  esac
fi

HELM_ARCH_DIR="linux-${ARCH_INPUT}"
TARBALL="helm-${HELM_VERSION}-${HELM_ARCH_DIR}.tar.gz"
OUT_DIR="$(cd "$(dirname "$0")"/.. && pwd)/charts/cache"
OUT_PATH="${OUT_DIR}/${TARBALL}"

PRIMARY_URL="https://get.helm.sh/${TARBALL}"
FALLBACK_URL="https://github.com/helm/helm/releases/download/${HELM_VERSION}/${TARBALL}"

mkdir -p "${OUT_DIR}"

echo "[prefetch-helm] Downloading ${TARBALL} -> ${OUT_PATH}" >&2
if ! curl -fL --retry 8 --retry-delay 2 --retry-all-errors --connect-timeout 25 --max-time 420 -o "${OUT_PATH}.tmp" "${PRIMARY_URL}"; then
  echo "[prefetch-helm][warn] Primary URL failed, trying fallback: ${FALLBACK_URL}" >&2
  rm -f "${OUT_PATH}.tmp"
  curl -fL --retry 8 --retry-delay 2 --retry-all-errors --connect-timeout 25 --max-time 420 -o "${OUT_PATH}.tmp" "${FALLBACK_URL}"
fi
mv -f "${OUT_PATH}.tmp" "${OUT_PATH}"

echo "[prefetch-helm] Done: ${OUT_PATH}" >&2
