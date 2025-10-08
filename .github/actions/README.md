# Reusable composite actions

This directory contains reusable composite actions for RuleHub workflows.

- guard-ci-image-tag: validates that `ci_image_tag` is not `latest` and nudges repos to set a pinned `CI_IMAGE_TAG` variable.
- probe-ghcr-image: probes local presence or anonymous pullability of an image (with `act` accommodation).

Usage from other repos (pin to a commit SHA):

- name: Guard ci_image_tag
  uses: rulehub/rulehub-ci-images/.github/actions/guard-ci-image-tag@<commit-sha>
  with:
  ci_image_tag: ${{ inputs.ci_image_tag }}

- name: Probe GHCR image
  id: probe
  uses: rulehub/rulehub-ci-images/.github/actions/probe-ghcr-image@<commit-sha>
  with:
  image: ghcr.io/${{ github.repository_owner }}/ci-base:${{ vars.CI_IMAGE_TAG }}
  assume_available_when_act: "true"

Note: for security and determinism, pin to a specific commit SHA rather than a branch ref like `main`.
