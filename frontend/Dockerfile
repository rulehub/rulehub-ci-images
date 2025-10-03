# syntax=docker/dockerfile:1.6

ARG BASE_REF=ghcr.io/<ORG>/ci-base:latest
# Under act, the workflow builds with classic docker and passes
#   --build-arg BASE_REF=ci-base:localtest
# so this FROM uses the locally tagged base image.
FROM ${BASE_REF}

LABEL org.opencontainers.image.source="https://github.com/<ORG>/rulehub-ci-images"
LABEL org.opencontainers.image.description="RuleHub CI overlay: frontend (Node toolchain)."

# Frontend-specific setup: use corepack (yarn/pnpm) without extra global installs.
USER root
RUN set -eux; \
    corepack enable; \
    node --version; npm --version; corepack --version || true
USER 1001
