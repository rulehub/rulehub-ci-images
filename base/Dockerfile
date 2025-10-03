# syntax=docker/dockerfile:1.6

ARG BASE_IMAGE=ubuntu:24.04
FROM ${BASE_IMAGE}

LABEL org.opencontainers.image.source="https://github.com/rulehub/rulehub-ci-images"
LABEL org.opencontainers.image.description="RuleHub CI base (Python 3.12, Node 20, jq, yq, syft, cosign, oras, mypy, pip-tools)."

ARG DEBIAN_FRONTEND=noninteractive
ARG NODE_MAJOR=20
ARG YQ_VERSION=4.44.3
ARG YQ_SHA256=""
ARG SYFT_VERSION=v1.22.0
ARG SYFT_TARBALL_SHA256=""
ARG COSIGN_VERSION=v2.6.0
ARG COSIGN_SHA256=""
ARG ORAS_VERSION=v1.2.2
ARG ORAS_TARBALL_SHA256=""
ARG TARGETARCH

# Base tooling
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends curl ca-certificates gnupg git jq tar xz-utils python3 python3-venv python3-pip; \
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /usr/share/keyrings/nodesource.gpg; \
    echo "deb [signed-by=/usr/share/keyrings/nodesource.gpg] https://deb.nodesource.com/node_${NODE_MAJOR}.x nodistro main" > /etc/apt/sources.list.d/nodesource.list; \
    apt-get update; \
    apt-get install -y --no-install-recommends nodejs; \
    npm --version; node --version; \
    rm -rf /var/lib/apt/lists/*

# yq (arch-aware)
RUN set -eux; \
    curl -fsSL -o /usr/local/bin/yq "https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/yq_linux_${TARGETARCH}"; \
    if [ -n "${YQ_SHA256}" ]; then echo "${YQ_SHA256}  /usr/local/bin/yq" | sha256sum -c -; fi; \
    chmod +x /usr/local/bin/yq; yq --version

# Syft, Cosign, ORAS (arch-aware)
RUN set -eux; \
    curl -fsSL -o /tmp/syft.tgz "https://github.com/anchore/syft/releases/download/${SYFT_VERSION}/syft_${SYFT_VERSION#v}_linux_${TARGETARCH}.tar.gz"; \
    if [ -n "${SYFT_TARBALL_SHA256}" ]; then echo "${SYFT_TARBALL_SHA256}  /tmp/syft.tgz" | sha256sum -c -; fi; \
    tar -xzf /tmp/syft.tgz -C /usr/local/bin syft; rm -f /tmp/syft.tgz; syft version; \
    curl -fsSL -o /usr/local/bin/cosign "https://github.com/sigstore/cosign/releases/download/${COSIGN_VERSION}/cosign-linux-${TARGETARCH}"; \
    if [ -n "${COSIGN_SHA256}" ]; then echo "${COSIGN_SHA256}  /usr/local/bin/cosign" | sha256sum -c -; fi; \
    chmod +x /usr/local/bin/cosign; cosign version; \
    curl -fsSL -o /tmp/oras.tgz "https://github.com/oras-project/oras/releases/download/${ORAS_VERSION}/oras_${ORAS_VERSION#v}_linux_${TARGETARCH}.tar.gz"; \
    if [ -n "${ORAS_TARBALL_SHA256}" ]; then echo "${ORAS_TARBALL_SHA256}  /tmp/oras.tgz" | sha256sum -c -; fi; \
    tar -xzf /tmp/oras.tgz -C /usr/local/bin oras; rm -f /tmp/oras.tgz; oras version

# Python CLI utilities commonly used in CI (installed into a dedicated venv)
ENV VENV_PATH=/opt/ci-venv
ENV PATH=${VENV_PATH}/bin:${PATH}
RUN set -eux; \
    python3 -m venv "${VENV_PATH}"; \
    . "${VENV_PATH}/bin/activate"; \
    pip install --upgrade pip; \
    pip install --no-cache-dir ruff pip-audit pip-tools mypy; \
    ruff --version; pip-audit --version || true; pip-compile --version; mypy --version

# Lightweight helper to create .venv and install project requirements
# Mirrors logic from repo's .github/scripts/python-venv-install.sh but defaults to system python3
USER root
# When building with context ./base, the scripts live at ./scripts in the context.
# Use relative path into the build context so COPY succeeds both in CI and local buildx runs.
COPY scripts/python-venv-install /usr/local/bin/python-venv-install
RUN chmod +x /usr/local/bin/python-venv-install

# Non-root user: create group/user and work directory while still root
RUN set -eux; \
    groupadd -g 1001 runner || true; \
    useradd -m -u 1001 -g 1001 runner || true; \
    mkdir -p /work; chown -R 1001:1001 /work

WORKDIR /work
USER 1001
