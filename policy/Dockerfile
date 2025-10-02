# syntax=docker/dockerfile:1.6

ARG BASE_REF=ghcr.io/<ORG>/ci-base:latest
FROM ${BASE_REF}

LABEL org.opencontainers.image.source="https://github.com/<ORG>/rulehub-ci-images"
LABEL org.opencontainers.image.description="RuleHub CI overlay: policy (OPA, Kyverno)."

ARG OPA_VERSION=1.7.1
ARG OPA_SHA256=""
ARG KYVERNO_VERSION=1.15.1
ARG KYVERNO_TARBALL_SHA256=""

USER root
# OPA (download with retries and a GitHub fallback)
RUN set -eux; \
    OPA_DEST=/usr/local/bin/opa; \
    OPA_URL_PRIMARY="https://openpolicyagent.org/downloads/v${OPA_VERSION}/opa_linux_amd64_static"; \
    OPA_URL_FALLBACK="https://github.com/open-policy-agent/opa/releases/download/v${OPA_VERSION}/opa_linux_amd64_static"; \
    # try primary URL with retries; if it fails, try GitHub releases URL
    # Use longer timeouts, more retries and allow resume (-C -) to handle slow/unstable networks
    (curl -fSL --retry 10 --retry-delay 5 --retry-connrefused --connect-timeout 15 --max-time 300 -C - -o "$OPA_DEST" "$OPA_URL_PRIMARY" ) || \
    (curl -fSL --retry 10 --retry-delay 5 --retry-connrefused --connect-timeout 15 --max-time 300 -C - -o "$OPA_DEST" "$OPA_URL_FALLBACK" ); \
    if [ -n "${OPA_SHA256}" ]; then echo "${OPA_SHA256}  $OPA_DEST" | sha256sum -c -; fi; \
    chmod +x $OPA_DEST; $OPA_DEST version

# Kyverno CLI
RUN set -eux; \
    curl -fsSL -o /tmp/kyverno.tar.gz "https://github.com/kyverno/kyverno/releases/download/v${KYVERNO_VERSION}/kyverno-cli_v${KYVERNO_VERSION}_linux_x86_64.tar.gz"; \
    if [ -n "${KYVERNO_TARBALL_SHA256}" ]; then echo "${KYVERNO_TARBALL_SHA256}  /tmp/kyverno.tar.gz" | sha256sum -c -; fi; \
    tar -xzf /tmp/kyverno.tar.gz -C /usr/local/bin kyverno; rm -f /tmp/kyverno.tar.gz; \
    kyverno version

USER 1001
