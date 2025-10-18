# syntax=docker/dockerfile:1.6

ARG BASE_REF=ghcr.io/rulehub/ci-base:latest
# Under act, the workflow builds overlays with classic docker build and passes
#   --build-arg BASE_REF=ci-base:localtest
# which makes this FROM consume the locally tagged base image.
FROM ${BASE_REF}

LABEL org.opencontainers.image.source="https://github.com/rulehub/rulehub-ci-images"
LABEL org.opencontainers.image.description="RuleHub CI overlay: policy (OPA, Kyverno)."
LABEL org.rulehub.tools.opa.version="${OPA_VERSION}"
LABEL org.rulehub.tools.kyverno.version="${KYVERNO_VERSION}"

ARG OPA_VERSION=1.8.0
# SHA256 (raw 64 hex) for static OPA binaries; prefer arch-specific overrides
ARG OPA_SHA256=""
ARG ENFORCE_CHECKSUMS=0
ARG OPA_SHA256_AMD64=""
ARG OPA_SHA256_ARM64=""
ARG OPA_EXTRA_VERSIONS="1.7.1 1.6.0"
ARG KYVERNO_VERSION=1.15.1
# SHA256 for kyverno CLI tarballs; prefer arch-specific overrides
ARG KYVERNO_CLI_SHA256=""
ARG KYVERNO_CLI_SHA256_AMD64=""
ARG KYVERNO_CLI_SHA256_ARM64=""
ARG TARGETARCH

USER root
# OPA (download with retries and a GitHub fallback)
RUN set -eux; \
    OPA_ARCH="${TARGETARCH}"; \
    case "$OPA_ARCH" in \
        amd64) EFFECTIVE_SHA="${OPA_SHA256_AMD64:-${OPA_SHA256:-}}" ;; \
        arm64) EFFECTIVE_SHA="${OPA_SHA256_ARM64:-${OPA_SHA256:-}}" ;; \
        *) EFFECTIVE_SHA="${OPA_SHA256:-}" ;; \
    esac; \
    OPA_DEST=/usr/local/bin/opa; \
    OPA_URL_PRIMARY="https://openpolicyagent.org/downloads/v${OPA_VERSION}/opa_linux_${OPA_ARCH}_static"; \
    OPA_URL_FALLBACK="https://github.com/open-policy-agent/opa/releases/download/v${OPA_VERSION}/opa_linux_${OPA_ARCH}_static"; \
    tmp_opa="/tmp/opa_${OPA_ARCH}"; \
    (curl -fSL --retry 10 --retry-delay 5 --retry-connrefused --connect-timeout 15 --max-time 300 -C - -o "$tmp_opa" "$OPA_URL_PRIMARY" ) || \
    (curl -fSL --retry 10 --retry-delay 5 --retry-connrefused --connect-timeout 15 --max-time 300 -C - -o "$tmp_opa" "$OPA_URL_FALLBACK" ); \
    if [ -n "$EFFECTIVE_SHA" ]; then echo "${EFFECTIVE_SHA}  $tmp_opa" | sha256sum -c -; elif [ "$ENFORCE_CHECKSUMS" = 1 ]; then echo "ERROR: OPA checksum required (ENFORCE_CHECKSUMS=1)" >&2; exit 1; else echo "WARNING: OPA SHA256 not provided; skipping verification" >&2; fi; \
        chmod +x "$tmp_opa"; mv "$tmp_opa" "$OPA_DEST"; $OPA_DEST version; \
        # Also keep a version-suffixed copy for selection
        cp -f "$OPA_DEST" "/usr/local/bin/opa-${OPA_VERSION}"; \
        # Pre-bake additional OPA versions for matrix selection (if any)
        for V in $OPA_EXTRA_VERSIONS; do \
            if [ "$V" = "$OPA_VERSION" ]; then continue; fi; \
            echo "Preparing OPA ${V} for ${OPA_ARCH}"; \
            URL_PRIMARY="https://openpolicyagent.org/downloads/v${V}/opa_linux_${OPA_ARCH}_static"; \
            URL_FALLBACK="https://github.com/open-policy-agent/opa/releases/download/v${V}/opa_linux_${OPA_ARCH}_static"; \
            tmp_opa_extra="/tmp/opa_${OPA_ARCH}_${V}"; \
            (curl -fSL --retry 10 --retry-delay 5 --retry-connrefused --connect-timeout 15 --max-time 300 -C - -o "$tmp_opa_extra" "$URL_PRIMARY" ) || \
            (curl -fSL --retry 10 --retry-delay 5 --retry-connrefused --connect-timeout 15 --max-time 300 -C - -o "$tmp_opa_extra" "$URL_FALLBACK" ); \
            chmod +x "$tmp_opa_extra"; mv "$tmp_opa_extra" "/usr/local/bin/opa-${V}"; \
            "/usr/local/bin/opa-${V}" version; \
        done; \
    # Provide an opa-select helper to switch versions at runtime
    cat >/usr/local/bin/opa-select <<'EOSH'
#!/usr/bin/env bash
set -euo pipefail
if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    echo "Usage: opa-select <version> [args...]" >&2
    echo "Invokes the requested OPA version if available (e.g., 1.6.0, 1.7.1, 1.8.0)." >&2
    exit 2
fi
VER="${1:-${OPA_VERSION:-}}"
if [ -z "$VER" ]; then
    echo "opa-select: version required (arg or OPA_VERSION env)" >&2
    exit 2
fi
if [ "${2:-}" = "--print-bin" ]; then
    printf "/usr/local/bin/opa-%s" "$VER"
    exit 0
fi
BIN="/usr/local/bin/opa-${VER}"
if [ ! -x "$BIN" ]; then
    # Fallback: if plain 'opa' matches version, use it.
    if command -v opa >/dev/null 2>&1 && opa version 2>/dev/null | grep -q "Version: ${VER}"; then
        shift || true
        exec opa "$@"
    fi
    echo "opa-select: OPA ${VER} not installed (expected $BIN)" >&2
    exit 1
fi
shift || true
exec "$BIN" "$@"
EOSH
    
# Make the selector executable in a separate layer
RUN chmod +x /usr/local/bin/opa-select

# Kyverno CLI
RUN set -eux; \
    ARCH_INPUT="${TARGETARCH}"; \
    case "$ARCH_INPUT" in \
        amd64) KYVERNO_ARCH=x86_64; EFFECTIVE_K_SHA="${KYVERNO_CLI_SHA256_AMD64:-${KYVERNO_CLI_SHA256:-}}" ;; \
        arm64) KYVERNO_ARCH=arm64; EFFECTIVE_K_SHA="${KYVERNO_CLI_SHA256_ARM64:-${KYVERNO_CLI_SHA256:-}}" ;; \
        *) KYVERNO_ARCH=x86_64; EFFECTIVE_K_SHA="${KYVERNO_CLI_SHA256:-}" ;; \
    esac; \
    curl -fsSL --retry 10 --retry-delay 5 --retry-connrefused -o /tmp/kyverno.tar.gz "https://github.com/kyverno/kyverno/releases/download/v${KYVERNO_VERSION}/kyverno-cli_v${KYVERNO_VERSION}_linux_${KYVERNO_ARCH}.tar.gz"; \
    if [ -n "$EFFECTIVE_K_SHA" ]; then echo "${EFFECTIVE_K_SHA}  /tmp/kyverno.tar.gz" | sha256sum -c -; elif [ "$ENFORCE_CHECKSUMS" = 1 ]; then echo "ERROR: Kyverno checksum required (ENFORCE_CHECKSUMS=1)" >&2; exit 1; else echo "WARNING: Kyverno CLI SHA256 not provided; skipping verification" >&2; fi; \
    tar -xzf /tmp/kyverno.tar.gz -C /usr/local/bin kyverno; rm -f /tmp/kyverno.tar.gz; \
    kyverno version

USER 1001
