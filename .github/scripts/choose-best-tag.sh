#!/usr/bin/env bash
set -euo pipefail

# choose-best-tag.sh
# Input: newline-separated full refs (e.g., ghcr.io/org/img:v1.2.3)
# Output: best tag value (e.g., v1.2.3) to stdout and writes GITHUB_OUTPUT key 'tag'

best=""
while IFS= read -r ref; do
  [[ -n "$ref" ]] || continue
  case "$ref" in
    *:v[0-9]*.[0-9]*.[0-9]*) best="$ref";;
    *:[0-9][0-9][0-9][0-9].*) if [[ -z "$best" ]]; then best="$ref"; fi;;
  esac
done

tag="${best##*:}"
echo "$tag"
if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  echo "tag=$tag" >> "$GITHUB_OUTPUT"
fi
