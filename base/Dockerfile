# syntax=docker/dockerfile:1.6

ARG BASE_IMAGE=ubuntu:24.04
FROM ${BASE_IMAGE}

LABEL org.opencontainers.image.source="https://github.com/rulehub/rulehub-ci-images"
LABEL org.opencontainers.image.description="RuleHub CI base (Python 3.12, Node 20, jq, yq, syft, grype, cosign, oras, mypy, pip-tools)."
LABEL org.rulehub.tools.pip_audit.version="${PIP_AUDIT_VERSION}"
LABEL org.rulehub.tools.node.major="${NODE_MAJOR}"
LABEL org.rulehub.tools.spectral.version="${SPECTRAL_VERSION}"
LABEL org.rulehub.tools.yq.version="${YQ_VERSION}"
LABEL org.rulehub.tools.syft.version="${SYFT_VERSION}"
LABEL org.rulehub.tools.grype.version="${GRYPE_VERSION}"
LABEL org.rulehub.tools.cosign.version="${COSIGN_VERSION}"
LABEL org.rulehub.tools.oras.version="${ORAS_VERSION}"
LABEL org.rulehub.tools.trivy.version="${TRIVY_VERSION}"

ARG DEBIAN_FRONTEND=noninteractive
ARG NODE_MAJOR=20
ARG YQ_VERSION=4.44.3
# Optional per-arch SHA256 (set via build args). If empty, checksum verification is skipped unless ENFORCE_CHECKSUMS=1.
ARG YQ_SHA256=""
ARG SYFT_VERSION=v1.22.0
ARG SYFT_TARBALL_SHA256=""
ARG GRYPE_VERSION=v0.69.1
ARG GRYPE_TARBALL_SHA256=""
ARG COSIGN_VERSION=v2.6.0
ARG COSIGN_SHA256=""
ARG ORAS_VERSION=v1.2.2
ARG ORAS_TARBALL_SHA256=""
ARG TRIVY_VERSION=v0.56.2
ARG TRIVY_TARBALL_SHA256=""
ARG TARGETARCH
ARG SKIP_TOOLS=0
ARG SKIP_VENV=0
ARG PIP_AUDIT_VERSION=2.7.3
ARG JSONSCHEMA_VERSION=4.23.0
ARG PYYAML_VERSION=6.0.2
ARG RUAMEL_YAML_VERSION=0.18.6
ARG LYCHEE_VERSION=v0.15.1
ARG LYCHEE_TARBALL_SHA256=""
ARG SPECTRAL_VERSION=6.11.1
ENV NPM_CONFIG_UPDATE_NOTIFIER=false

# Base tooling
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends curl ca-certificates gnupg git jq tar xz-utils make python3 python3-venv python3-pip; \
    curl -fSL --retry 5 --retry-delay 3 --retry-connrefused https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /usr/share/keyrings/nodesource.gpg; \
    echo "deb [signed-by=/usr/share/keyrings/nodesource.gpg] https://deb.nodesource.com/node_${NODE_MAJOR}.x nodistro main" > /etc/apt/sources.list.d/nodesource.list; \
    apt-get update; \
    apt-get install -y --no-install-recommends nodejs; \
    npm --version; node --version; \
    rm -rf /var/lib/apt/lists/*

# Add deadsnakes PPA and install additional Python versions (3.11, 3.13)
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends software-properties-common; \
    add-apt-repository -y ppa:deadsnakes/ppa; \
    apt-get update; \
    apt-get install -y --no-install-recommends python3.11 python3.11-venv python3.11-distutils python3.13 python3.13-venv; \
    python3 --version; python3.11 --version; python3.13 --version; \
    rm -rf /var/lib/apt/lists/*

# Preinstall Spectral CLI (pinned) to avoid npx downloads at runtime
RUN set -eux; \
    npm config set update-notifier false; \
    npm install -g --no-audit --no-fund @stoplight/spectral-cli@"${SPECTRAL_VERSION}"; \
    spectral --version

COPY scripts/install-binaries.sh /tmp/install-binaries.sh
ENV SKIP_TOOLS=${SKIP_TOOLS}
RUN chmod +x /tmp/install-binaries.sh && /tmp/install-binaries.sh && rm -f /tmp/install-binaries.sh

# Python CLI utilities commonly used in CI (installed into a dedicated venv)
ENV VENV_PATH=/opt/ci-venv
ENV PATH=${VENV_PATH}/bin:${PATH}
ENV PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DEFAULT_TIMEOUT=60

COPY requirements-tools.txt /tmp/requirements-tools.txt
# Fast-fail if placeholder hashes accidentally remain
RUN grep -qv 'REPLACE' /tmp/requirements-tools.txt || (echo 'ERROR: requirements-tools.txt contains placeholder hash markers (REPLACE). Regenerate via docs/REGENERATE_REQUIREMENTS_TOOLS.md' >&2; exit 1)
ENV SKIP_VENV=${SKIP_VENV}
RUN set -eux; \
        if [ "${SKIP_VENV}" = "1" ]; then \
            echo "[base][warn] SKIP_VENV=1: skipping Python venv tool installation for local/act build"; \
            rm -f /tmp/requirements-tools.txt; \
        else \
            python3 -m venv "${VENV_PATH}"; \
            . "${VENV_PATH}/bin/activate"; \
            pip install --no-cache-dir --require-hashes -r /tmp/requirements-tools.txt || pip install --no-cache-dir -r /tmp/requirements-tools.txt; \
            ruff --version; pip-audit --version || true; pip-compile --version; mypy --version; yamllint --version; mkdocs --version; \
            rm -f /tmp/requirements-tools.txt; \
        fi

# Lightweight helper to create .venv and install project requirements
# Mirrors logic from repo's .github/scripts/python-venv-install.sh but defaults to system python3
USER root
# When building with context ./base, the scripts live at ./scripts in the context.
# Use relative path into the build context so COPY succeeds both in CI and local buildx runs.
COPY scripts/python-venv-install /usr/local/bin/python-venv-install
RUN chmod +x /usr/local/bin/python-venv-install

# Lightweight helper to select a Python version (execs pythonX.Y)
COPY scripts/python-select /usr/local/bin/python-select
RUN chmod +x /usr/local/bin/python-select

# Non-root user: create group/user and work directory while still root
RUN set -eux; \
    groupadd -g 1001 runner || true; \
    useradd -m -u 1001 -g 1001 runner || true; \
    mkdir -p /work; chown -R 1001:1001 /work

WORKDIR /work
USER 1001
