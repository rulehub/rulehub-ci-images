# syntax=docker/dockerfile:1.6

ARG BASE_REF=ghcr.io/<ORG>/ci-base:latest
# Under act, overlays are built with classic docker build and
#   --build-arg BASE_REF=ci-base:localtest
# so this FROM consumes the locally tagged base image from the daemon.
FROM ${BASE_REF}

LABEL org.opencontainers.image.source="https://github.com/<ORG>/rulehub-ci-images"
LABEL org.opencontainers.image.description="RuleHub CI overlay: charts (Helm, kubeconform, helm-unittest)."

ARG HELM_VERSION=v3.15.3
ARG HELM_TARBALL_SHA256=""
ARG KUBECONFORM_VERSION=v0.6.7
ARG KUBECONFORM_TARBALL_SHA256=""
ARG HELM_UNITTEST_VERSION=0.5.1
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

USER 1001
