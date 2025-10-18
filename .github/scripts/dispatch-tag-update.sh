#!/usr/bin/env bash
set -euo pipefail

# dispatch-tag-update.sh
# Usage: dispatch-tag-update.sh <owner> <tag>
# Env:
#   DISPATCH_TOKEN (optional) - GitHub token with repo:actions scope on target repo
#   GITHUB_STEP_SUMMARY (optional) - for step summary output

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <owner> <tag>" >&2
  exit 2
fi

OWNER="$1"
TAG="$2"
TOKEN="${DISPATCH_TOKEN:-}"

summary() {
  if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
    echo "$*" >> "$GITHUB_STEP_SUMMARY"
  else
    echo "$*"
  fi
}

if [[ -z "$TOKEN" ]]; then
  summary "DISPATCH_TOKEN not set; skipping repository_dispatch to ${OWNER}/rulehub-charts"
  exit 0
fi

# Ensure ci-charts image already published with the same tag
echo "Checking existence of ghcr.io/${OWNER}/ci-charts:${TAG}..."
if ! docker manifest inspect "ghcr.io/${OWNER}/ci-charts:${TAG}" >/dev/null 2>&1; then
  summary "ci-charts:${TAG} not found; skipping repository_dispatch (will be updated by ci-charts workflow)."
  exit 0
fi

echo "Dispatching ci-image-published to ${OWNER}/rulehub-charts with tag=${TAG}"
payload=$(printf '{"event_type":"ci-image-published","client_payload":{"tag":"%s"}}' "$TAG")
curl -sSf -X POST \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  "https://api.github.com/repos/${OWNER}/rulehub-charts/dispatches" \
  -d "$payload"

summary "repository_dispatch sent to ${OWNER}/rulehub-charts"
