#!/usr/bin/env bash
set -euo pipefail

# retag-and-push.sh
# Reads newline-separated refs from stdin and retags/pushes local image REG/IMAGE:latest
# Env:
#   REG, IMAGE
#   PUSH=1 to push; otherwise only tag

REG=${REG:-}
IMAGE=${IMAGE:-}
if [[ -z "$REG" || -z "$IMAGE" ]]; then
  echo "REG and IMAGE env vars are required" >&2
  exit 2
fi

while IFS= read -r ref; do
  [[ -n "$ref" ]] || continue
  echo "Tagging ${REG}/${IMAGE}:latest as $ref"
  docker tag "${REG}/${IMAGE}:latest" "$ref"
  if [[ "${PUSH:-0}" == "1" ]]; then
    echo "Pushing $ref"
    docker push "$ref"
  fi
done
