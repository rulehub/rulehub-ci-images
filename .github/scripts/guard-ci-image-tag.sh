#!/usr/bin/env bash
set -euo pipefail

# Enforce non-latest immutable CI image tag unless running under local act.
# Accepted immutable formats:
#  - vMAJOR.MINOR.PATCH (optionally with pre-release/build metadata)
#  - YYYY.MM.DD-<sha>

INPUT_TAG="${1:-${INPUT_TAG:-}}"
ENV_TAG="${CI_IMAGE_TAG:-}"

is_act_env() {
  if [[ "${ACT:-}" == "true" || "${IS_ACT:-}" == "true" ]]; then
    return 0
  fi
  case "${GITHUB_WORKSPACE:-}" in
    /github/*) return 0 ;;
  esac
  return 1
}

ACT_MODE=false
if [[ "${ACT_STRICT:-}" == "1" ]]; then
  ACT_MODE=false
else
  if is_act_env; then ACT_MODE=true; fi
fi

is_valid_immutable_tag() {
  local tag="$1"
  [[ "$tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+([-.][0-9A-Za-z]+)*$ ]] && return 0
  [[ "$tag" =~ ^[0-9]{4}\.[0-9]{2}\.[0-9]{2}-[0-9a-f]{7,40}$ ]] && return 0
  return 1
}

# If explicit input is provided
if [[ -n "${INPUT_TAG}" ]]; then
  if [[ "$ACT_MODE" == true && ( "${INPUT_TAG}" == "dev-local" || "${INPUT_TAG}" == "latest" ) ]]; then
    echo "Note: ci_image_tag='${INPUT_TAG}' allowed under act (dev/local)." >&2
    exit 0
  fi
  if [[ "${INPUT_TAG}" == "latest" ]]; then
    if [[ "$ACT_MODE" == true ]]; then
      echo "Note: ci_image_tag input is 'latest' (allowed under act); prefer immutable tag for CI." >&2
      exit 0
    fi
    echo "ci_image_tag must not be 'latest' in CI. Use an immutable tag (e.g., 2025.10.03-<sha> or vX.Y.Z)." >&2
    exit 1
  fi
  if ! is_valid_immutable_tag "${INPUT_TAG}"; then
    echo "ci_image_tag='${INPUT_TAG}' is not an accepted immutable tag. Use 'vMAJOR.MINOR.PATCH' or 'YYYY.MM.DD-<sha>'." >&2
    exit 1
  fi
  exit 0
fi

# No explicit input -> rely on CI_IMAGE_TAG (org/repo variable)
if [[ -z "${INPUT_TAG}" ]]; then
  if [[ "$ACT_MODE" == true ]]; then
    if [[ -z "${ENV_TAG}" ]]; then
      echo "Note: ci_image_tag not provided. Under act, proceeding without a pinned tag (dev/local)." >&2
      exit 0
    fi
    if [[ "${ENV_TAG}" == "latest" || "${ENV_TAG}" == dev-local ]]; then
      echo "Note: CI_IMAGE_TAG='${ENV_TAG}' allowed under act; prefer immutable tag for CI." >&2
      exit 0
    fi
    if is_valid_immutable_tag "${ENV_TAG}"; then
      echo "Note: Using CI_IMAGE_TAG='${ENV_TAG}'." >&2
      exit 0
    else
      echo "Note: CI_IMAGE_TAG='${ENV_TAG}' does not match immutable patterns; allowed under act but should be corrected for CI." >&2
      exit 0
    fi
  fi

  if [[ -z "${ENV_TAG}" ]]; then
    echo "ci_image_tag not provided and CI_IMAGE_TAG unset. Define CI_IMAGE_TAG to an immutable tag to avoid drift." >&2
    exit 1
  fi
  if [[ "${ENV_TAG}" == "latest" ]]; then
    echo "CI_IMAGE_TAG must not be 'latest'. Use an immutable tag (e.g., 2025.10.03-<sha> or vX.Y.Z)." >&2
    exit 1
  fi
  if ! is_valid_immutable_tag "${ENV_TAG}"; then
    echo "CI_IMAGE_TAG='${ENV_TAG}' is not an accepted immutable tag. Use 'vMAJOR.MINOR.PATCH' or 'YYYY.MM.DD-<sha>'." >&2
    exit 1
  fi
  echo "Using CI_IMAGE_TAG='${ENV_TAG}'." >&2
fi

exit 0
