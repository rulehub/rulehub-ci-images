# RuleHub CI Images

[![build-publish](https://github.com/rulehub/rulehub-ci-images/actions/workflows/build-publish.yml/badge.svg?branch=main)](https://github.com/rulehub/rulehub-ci-images/actions/workflows/build-publish.yml)
[![build-publish-ci-base-rulehub](https://github.com/rulehub/rulehub-ci-images/actions/workflows/build-publish-rulehub.yml/badge.svg?branch=main)](https://github.com/rulehub/rulehub-ci-images/actions/workflows/build-publish-rulehub.yml)

Centralized CI container images used across RuleHub repositories. Provides a shared base image and small overlays per repo domain.

- Base: `ghcr.io/rulehub/ci-base`
  - Common tooling: Python 3.11, Node 20, git, jq, yq, syft, cosign, oras, non-root user.
- Overlays:
  - Policy: `ghcr.io/rulehub/ci-policy` (adds opa, kyverno)
  - Charts: `ghcr.io/rulehub/ci-charts` (adds helm, kubeconform, helm-unittest)
  - Frontend: `ghcr.io/rulehub/ci-frontend` (adds Node tooling specifics)

## Versioning & Triggers

- Tag by semver (e.g., v1.0.0) and publish immutable digests.
- Triggers: push to main, tagged releases (`v*`), and manual dispatch (workflow_dispatch).
- Scheduled weekly rebuilds are currently disabled; re‑enable in CI if needed.

## Security

- SBOM generation and vulnerability scan run in CI and fail on CRITICAL findings.
- Build provenance is emitted (BuildKit provenance) for pushed images.
- Image signing with cosign (keyless, OIDC) is planned; verify provenance/SBOMs in downstream pipelines.

## Usage

Reference overlays by digest in workflows:

```yaml
container:
  image: ghcr.io/rulehub/ci-policy@sha256:<digest>
```

## Structure

- `base/` – base image Dockerfile
- `policy/` – overlay for policy repo
- `charts/` – overlay for Helm charts repo
- `frontend/` – overlay for Backstage plugin repo

## Prebuilt base with repository deps

For faster CI runs you can bake the RuleHub repository Python dependencies into
the base image. This creates a variant image `ci-base-rulehub` that already
contains the Python packages from the sibling `rulehub/requirements*.txt`.

Build locally from the repo root (so the build context contains the `rulehub/`
directory):

```sh
make base-rulehub
```

The Makefile target builds `base/Dockerfile.rulehub` and tags it as
`$(REG)/ci-base-rulehub:$(BASE_REF)`.

Example (by digest):

```yaml
container:
  image: ghcr.io/rulehub/ci-base-rulehub@sha256:<digest>
```

## License

MIT — see the `LICENSE` file for details.
