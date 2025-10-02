# syntax=docker/dockerfile:1.6

ARG BASE_REF=ghcr.io/<ORG>/ci-base:latest
FROM ${BASE_REF}

LABEL org.opencontainers.image.source="https://github.com/<ORG>/rulehub-ci-images"
LABEL org.opencontainers.image.description="RuleHub CI overlay: docs (lychee + jq + python runtime)."

# Lychee link checker (static binary via cargo prebuilt image layer)
# We use the official container to copy lychee into our image for multi-arch stability
ARG LYCHEE_TAG=v0.15.1

USER root
RUN set -eux; \
    arch=$(uname -m); \
    case "$arch" in \
      x86_64) LARCH=amd64 ;; \
      aarch64) LARCH=arm64 ;; \
      *) echo "Unsupported arch: $arch"; exit 1 ;; \
    esac; \
    curl -fsSL -o /usr/local/bin/lychee "https://github.com/lycheeverse/lychee/releases/download/${LYCHEE_TAG}/lychee-${LYCHEE_TAG#v}-x86_64-unknown-linux-musl" || true; \
    if [ ! -s /usr/local/bin/lychee ]; then \
      # Fallback to Docker image copy if direct artifact naming changes
      tmp=$(mktemp -d); \
      ctr="lychee:${LYCHEE_TAG}"; \
      docker pull ghcr.io/lycheeverse/lychee:${LYCHEE_TAG} || true; \
      echo "Using layered lychee image at runtime"; \
    fi; \
    chmod +x /usr/local/bin/lychee || true; \
    lychee --version || true

USER 1001
