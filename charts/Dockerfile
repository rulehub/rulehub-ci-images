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

ARG HELM_VERSION=v3.19.0
ARG HELM_TARBALL_SHA256=""
ARG KUBECONFORM_VERSION=v0.6.7
ARG KUBECONFORM_TARBALL_SHA256=""
ARG HELM_UNITTEST_VERSION=0.5.1
ARG CT_VERSION=v3.10.1
ARG TARGETARCH
ARG YQ_VERSION=4.44.3
ARG YQ_SHA256=""

# Optional pre-fetched cache: if charts/cache is provided in the build context,
# it can be copied in a prior step. In CI/act contexts where it's absent, we
# proceed without local cache and rely on resilient downloads below.

USER root
# Ensure yq v4 is available even if the base image was built without tools (SKIP_TOOLS)
RUN set -eux; \
        if command -v yq >/dev/null 2>&1; then \
            echo "[charts] yq already present:"; yq --version; \
        else \
            echo "[charts] installing yq v${YQ_VERSION}"; \
            # yq release asset names use underscores in the OS/arch fragment, e.g., yq_linux_amd64
            YQ_ARCH="amd64"; \
            if [ "${TARGETARCH}" = "arm64" ]; then YQ_ARCH="arm64"; fi; \
            curl -fsSL -o /usr/local/bin/yq "https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/yq_linux_${YQ_ARCH}"; \
            if [ -n "${YQ_SHA256}" ]; then echo "${YQ_SHA256}  /usr/local/bin/yq" | sha256sum -c -; fi; \
            chmod +x /usr/local/bin/yq; \
            yq --version; \
        fi
# Helm
RUN set -eux; \
    diag_net() { \
        H="$1"; echo "[charts][diag] Host: $H"; \
        date -u | sed 's/^/[charts][diag] /'; \
        echo "[charts][diag] resolv.conf:"; sed 's/^/[charts][diag]   /' /etc/resolv.conf || true; \
        echo "[charts][diag] getent hosts:"; getent hosts "$H" | sed 's/^/[charts][diag]   /' || true; \
        echo "[charts][diag] getent ahostsv4:"; getent ahostsv4 "$H" | sed 's/^/[charts][diag]   /' || true; \
        if command -v ip >/dev/null 2>&1; then ip route get 1.1.1.1 | sed 's/^/[charts][diag] route: /' || true; fi; \
        if command -v openssl >/dev/null 2>&1; then \
          echo "[charts][diag] openssl s_client (tls1.2, 10s):"; \
          timeout 10s openssl s_client -servername "$H" -connect "$H:443" -brief -tls1_2 < /dev/null | sed 's/^/[charts][diag]   ssl: /' || true; \
        fi; \
    }; \
    curl_head_metrics() { \
      URL="$1"; \
      echo "[charts][diag] preflight HEAD: $URL"; \
      curl -4sSIL --http1.1 --connect-timeout 10 --max-time 20 "$URL" -o /dev/null \
        -w "[charts][diag] curl metrics code=%{http_code} ip=%{remote_ip} port=%{remote_port} timing name=%{time_namelookup} connect=%{time_connect} appconnect=%{time_appconnect} starttx=%{time_starttransfer} total=%{time_total}\n" || true; \
    }; \
    HELM_ARCH_DIR="linux-amd64"; \
    if [ "${TARGETARCH}" = "arm64" ]; then HELM_ARCH_DIR="linux-arm64"; fi; \
    HELM_TARBALL="helm-${HELM_VERSION}-${HELM_ARCH_DIR}.tar.gz"; \
    PRIMARY_URL="${HELM_BASE_URL:-https://get.helm.sh}/${HELM_TARBALL}"; \
    FALLBACK_URL="${HELM_GITHUB_BASE_URL:-https://github.com/helm/helm/releases/download}/${HELM_VERSION}/${HELM_TARBALL}"; \
    if [ -f "/opt/charts-cache/${HELM_TARBALL}" ]; then \
        echo "[charts] Using cached Helm tarball: /opt/charts-cache/${HELM_TARBALL}"; \
        cp "/opt/charts-cache/${HELM_TARBALL}" /tmp/helm.tgz; \
    else \
        echo "[charts] Attempting Helm download from: $PRIMARY_URL"; \
        curl_head_metrics "$PRIMARY_URL"; \
        if ! curl -4fL -# --retry 8 --retry-delay 2 --retry-all-errors --connect-timeout 25 --max-time 420 -o /tmp/helm.tgz "$PRIMARY_URL"; then \
            echo "[charts][warn] Primary Helm URL failed with exit=$?"; \
            diag_net "$(printf %s "$PRIMARY_URL" | sed -E 's#^[a-z]+://([^/]+)/.*#\1#')"; \
            echo "[charts][warn] Trying fallback: $FALLBACK_URL"; \
            rm -f /tmp/helm.tgz; \
            curl_head_metrics "$FALLBACK_URL"; \
            curl -4fL -# --retry 8 --retry-delay 2 --retry-all-errors --connect-timeout 25 --max-time 420 -o /tmp/helm.tgz "$FALLBACK_URL"; \
        fi; \
    fi; \
    if [ -n "${HELM_TARBALL_SHA256}" ]; then echo "${HELM_TARBALL_SHA256}  /tmp/helm.tgz" | sha256sum -c -; fi; \
    tar -xzf /tmp/helm.tgz -C /tmp ${HELM_ARCH_DIR}/helm; mv /tmp/${HELM_ARCH_DIR}/helm /usr/local/bin/helm; \
    BYTES=$(wc -c </tmp/helm.tgz || echo 0); echo "[charts] Helm tarball size: ${BYTES} bytes"; \
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
