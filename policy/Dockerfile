# syntax=docker/dockerfile:1.6

ARG BASE_REF=ghcr.io/<ORG>/ci-base:latest
# Under act, the workflow builds overlays with classic docker build and passes
#   --build-arg BASE_REF=ci-base:localtest
# which makes this FROM consume the locally tagged base image.
FROM ${BASE_REF}

LABEL org.opencontainers.image.source="https://github.com/<ORG>/rulehub-ci-images"
LABEL org.opencontainers.image.description="RuleHub CI overlay: policy (OPA, Kyverno)."

ARG OPA_VERSION=1.7.1
ARG OPA_SHA256=""
ARG KYVERNO_VERSION=1.15.1
ARG KYVERNO_TARBALL_SHA256=""
ARG TARGETARCH

USER root
# OPA (download with retries and a GitHub fallback)
RUN set -eux; \
    OPA_DEST=/usr/local/bin/opa; \
    OPA_ARCH="${TARGETARCH}"; \
    OPA_URL_PRIMARY="https://openpolicyagent.org/downloads/v${OPA_VERSION}/opa_linux_${OPA_ARCH}_static"; \
    OPA_URL_FALLBACK="https://github.com/open-policy-agent/opa/releases/download/v${OPA_VERSION}/opa_linux_${OPA_ARCH}_static"; \
    # try primary URL with retries; if it fails, try GitHub releases URL
    # Use longer timeouts, more retries and allow resume (-C -) to handle slow/unstable networks
    (curl -fSL --retry 10 --retry-delay 5 --retry-connrefused --connect-timeout 15 --max-time 300 -C - -o "$OPA_DEST" "$OPA_URL_PRIMARY" ) || \
    (curl -fSL --retry 10 --retry-delay 5 --retry-connrefused --connect-timeout 15 --max-time 300 -C - -o "$OPA_DEST" "$OPA_URL_FALLBACK" ); \
    if [ -n "${OPA_SHA256}" ]; then echo "${OPA_SHA256}  $OPA_DEST" | sha256sum -c -; fi; \
    chmod +x $OPA_DEST; $OPA_DEST version

# Kyverno CLI
RUN set -eux; \
        # Map TARGETARCH to kyverno asset arch name (amd64->x86_64, arm64->arm64)
        case "${TARGETARCH}" in \
            amd64) KYVERNO_ARCH=x86_64 ;; \
            arm64) KYVERNO_ARCH=arm64 ;; \
            *) KYVERNO_ARCH=x86_64 ;; \
        esac; \
        curl -fsSL -o /tmp/kyverno.tar.gz "https://github.com/kyverno/kyverno/releases/download/v${KYVERNO_VERSION}/kyverno-cli_v${KYVERNO_VERSION}_linux_${KYVERNO_ARCH}.tar.gz"; \
    if [ -n "${KYVERNO_TARBALL_SHA256}" ]; then echo "${KYVERNO_TARBALL_SHA256}  /tmp/kyverno.tar.gz" | sha256sum -c -; fi; \
    tar -xzf /tmp/kyverno.tar.gz -C /usr/local/bin kyverno; rm -f /tmp/kyverno.tar.gz; \
    kyverno version

USER 1001
