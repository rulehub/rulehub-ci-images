# syntax=docker/dockerfile:1.6

ARG BASE_REF=ghcr.io/rulehub/ci-base:latest
# Under act, overlays are built with classic docker build and
#   --build-arg BASE_REF=ci-base:localtest
# so this FROM consumes the locally tagged base image from the daemon.
FROM ${BASE_REF}

LABEL org.opencontainers.image.source="https://github.com/rulehub/rulehub-ci-images"
LABEL org.opencontainers.image.description="RuleHub CI overlay: charts (Helm, kubeconform, helm-unittest) atop ci-base (jq, yq, syft, grype, cosign, oras)."
LABEL org.rulehub.tools.helm.version="${HELM_VERSION}"
LABEL org.rulehub.tools.kubeconform.version="${KUBECONFORM_VERSION}"
LABEL org.rulehub.tools.helm_unittest.version="${HELM_UNITTEST_VERSION}"

ARG HELM_VERSION=v3.15.3
ARG HELM_TARBALL_SHA256=""
ARG KUBECONFORM_VERSION=v0.6.7
ARG KUBECONFORM_TARBALL_SHA256=""
ARG HELM_UNITTEST_VERSION=0.5.1
ARG CT_VERSION=v3.10.1
ARG TARGETARCH

USER root
# Helm
RUN set -eux; \
    HELM_ARCH_DIR="linux-amd64"; \
    if [ "${TARGETARCH}" = "arm64" ]; then HELM_ARCH_DIR="linux-arm64"; fi; \
    curl -fsSL -o /tmp/helm.tgz "https://get.helm.sh/helm-${HELM_VERSION}-${HELM_ARCH_DIR}.tar.gz"; \
    if [ -n "${HELM_TARBALL_SHA256}" ]; then echo "${HELM_TARBALL_SHA256}  /tmp/helm.tgz" | sha256sum -c -; fi; \
    tar -xzf /tmp/helm.tgz -C /tmp ${HELM_ARCH_DIR}/helm; mv /tmp/${HELM_ARCH_DIR}/helm /usr/local/bin/helm; \
    rm -rf /tmp/helm.tgz /tmp/${HELM_ARCH_DIR}; helm version --short

# kubeconform
RUN set -eux; \
    KUBECONFORM_ARCH="amd64"; \
    if [ "${TARGETARCH}" = "arm64" ]; then KUBECONFORM_ARCH="arm64"; fi; \
    curl -fsSL -o /tmp/kubeconform.tgz "https://github.com/yannh/kubeconform/releases/download/${KUBECONFORM_VERSION}/kubeconform-linux-${KUBECONFORM_ARCH}.tar.gz"; \
    if [ -n "${KUBECONFORM_TARBALL_SHA256}" ]; then echo "${KUBECONFORM_TARBALL_SHA256}  /tmp/kubeconform.tgz" | sha256sum -c -; fi; \
    tar -xzf /tmp/kubeconform.tgz -C /usr/local/bin kubeconform; rm -f /tmp/kubeconform.tgz; \
    kubeconform -v

# helm-unittest plugin (local install in PATH)
RUN set -eux; \
    HELM_PLUGINS_DIR=/usr/local/helm-plugins; mkdir -p "$HELM_PLUGINS_DIR"; \
    export HELM_PLUGINS="$HELM_PLUGINS_DIR"; \
    helm plugin install https://github.com/helm-unittest/helm-unittest --version ${HELM_UNITTEST_VERSION}; \
    helm unittest --help >/dev/null

# pre-commit
# CI path: install into the base venv. act/local path (SKIP_VENV=1): create a small local venv to avoid
# Debian's externally-managed PEP 668 restriction on system-wide pip installs.
RUN set -eux; \
    if [ -n "${VENV_PATH:-}" ] && [ -f "${VENV_PATH}/bin/activate" ] && [ "${SKIP_VENV:-0}" != "1" ]; then \
        . "${VENV_PATH}/bin/activate"; \
        pip install --no-cache-dir --upgrade pre-commit; \
        pre-commit --version; \
    else \
        echo "[charts][warn] VENV not available or SKIP_VENV=1; creating local venv for pre-commit"; \
        CHARTS_VENV="/opt/charts-venv"; \
        python3 -m venv "$CHARTS_VENV"; \
        "$CHARTS_VENV/bin/pip" install --no-cache-dir --upgrade pip; \
        "$CHARTS_VENV/bin/pip" install --no-cache-dir --upgrade pre-commit; \
        ln -sf "$CHARTS_VENV/bin/pre-commit" /usr/local/bin/pre-commit; \
        pre-commit --version; \
    fi

# chart-testing (ct) CLI
RUN set -eux; \
    CT_ARCH="amd64"; \
    if [ "${TARGETARCH}" = "arm64" ]; then CT_ARCH="arm64"; fi; \
    curl -fsSL -o /tmp/ct.tgz "https://github.com/helm/chart-testing/releases/download/${CT_VERSION}/chart-testing_${CT_VERSION#v}_linux_${CT_ARCH}.tar.gz"; \
    TMP_DIR="$(mktemp -d)"; \
    tar -xzf /tmp/ct.tgz -C "$TMP_DIR"; \
    CT_BIN_PATH="$(find "$TMP_DIR" -type f -name ct -perm -011 -print -quit || true)"; \
    if [ -z "$CT_BIN_PATH" ]; then CT_BIN_PATH="$(find "$TMP_DIR" -type f -name ct -print -quit || true)"; fi; \
    if [ -z "$CT_BIN_PATH" ]; then echo "ct binary not found in archive" >&2; exit 1; fi; \
    install -m 0755 "$CT_BIN_PATH" /usr/local/bin/ct; \
    rm -rf /tmp/ct.tgz "$TMP_DIR"; \
    ct version || ct --help

USER 1001
