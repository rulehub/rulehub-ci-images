#!/usr/bin/env bash
set -euo pipefail

# compute-tags.sh
# Outputs multi-line list of image refs into $GITHUB_OUTPUT as key 'tags'.
# Env:
#   REG   - registry/org prefix (e.g., ghcr.io/<owner>)
#   IMAGE - image name (e.g., ci-base-rulehub)
#   GITHUB_REF_TYPE, GITHUB_REF_NAME, GITHUB_SHA - provided by GitHub

REG=${REG:-}
IMAGE=${IMAGE:-}
if [[ -z "$REG" || -z "$IMAGE" ]]; then
  echo "REG and IMAGE env vars are required" >&2
  exit 2
fi

TAGS="${REG}/${IMAGE}:latest"
DATE_UTC=$(date -u +%Y.%m.%d)
SHORT_SHA=${GITHUB_SHA::8}
TAGS+=$'\n'"${REG}/${IMAGE}:${DATE_UTC}-${SHORT_SHA}"
if [[ "${GITHUB_REF_TYPE:-}" == "tag" ]] && [[ "${GITHUB_REF_NAME:-}" =~ ^v([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
  MAJOR="${BASH_REMATCH[1]}"; MINOR="${BASH_REMATCH[2]}"; PATCH="${BASH_REMATCH[3]}"
  TAGS+=$'\n'"${REG}/${IMAGE}:v${MAJOR}.${MINOR}.${PATCH}"
  TAGS+=$'\n'"${REG}/${IMAGE}:v${MAJOR}.${MINOR}"
  TAGS+=$'\n'"${REG}/${IMAGE}:v${MAJOR}"
fi
{
  echo "tags<<EOF"
  echo "$TAGS"
  echo "EOF"
} >> "${GITHUB_OUTPUT}"
