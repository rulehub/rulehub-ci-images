#!/usr/bin/env bash
# Build all RuleHub CI images locally with a single immutable tag.
# Uses the local Docker daemon; no registry login required.
#
# Environment:
#   CI_IMAGE_TAG   - required tag to apply (e.g., 2025.01.01-00000000 or v1.2.3)
#   OWNER          - optional, GitHub org/user (default: rulehub)
#   REG            - optional, full registry path (default: ghcr.io/${OWNER})
#
# Example:
#   CI_IMAGE_TAG=2025.01.01-00000000 ./hack/build-local-ci-images.sh

set -euo pipefail

TAG="${CI_IMAGE_TAG:-}"
if [[ -z "${TAG}" ]]; then
  echo "CI_IMAGE_TAG must be set (e.g., 2025.01.01-00000000)" >&2
  exit 1
fi

OWNER_DEFAULT="rulehub"
OWNER="${OWNER:-$OWNER_DEFAULT}"
REG="${REG:-ghcr.io/${OWNER}}"

echo "Building RuleHub CI images locally with tag: ${TAG} (REG=${REG})"

# Build base image
echo "[1/4] Building ci-base:${TAG}"
DOCKER_BUILDKIT=1 docker build \
  -t "${REG}/ci-base:${TAG}" \
  ./base

# Build policy image (uses base)
echo "[2/4] Building ci-policy:${TAG}"
DOCKER_BUILDKIT=1 docker build \
  --build-arg BASE_REF="${REG}/ci-base:${TAG}" \
  -t "${REG}/ci-policy:${TAG}" \
  ./policy

# Build charts image (uses base)
echo "[3/4] Building ci-charts:${TAG}"
DOCKER_BUILDKIT=1 docker build \
  --build-arg BASE_REF="${REG}/ci-base:${TAG}" \
  -t "${REG}/ci-charts:${TAG}" \
  ./charts

# Build frontend image (uses base)
echo "[4/4] Building ci-frontend:${TAG}"
DOCKER_BUILDKIT=1 docker build \
  --build-arg BASE_REF="${REG}/ci-base:${TAG}" \
  -t "${REG}/ci-frontend:${TAG}" \
  ./frontend

echo "Done. Locally available images:"
echo "  ${REG}/ci-base:${TAG}"
echo "  ${REG}/ci-policy:${TAG}"
echo "  ${REG}/ci-charts:${TAG}"
echo "  ${REG}/ci-frontend:${TAG}"
