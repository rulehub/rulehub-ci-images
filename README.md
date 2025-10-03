# RuleHub CI Images

[![build-publish](https://github.com/rulehub/rulehub-ci-images/actions/workflows/build-publish.yml/badge.svg?branch=main)](https://github.com/rulehub/rulehub-ci-images/actions/workflows/build-publish.yml)
[![build-publish-ci-base-rulehub](https://github.com/rulehub/rulehub-ci-images/actions/workflows/build-publish-rulehub.yml/badge.svg?branch=main)](https://github.com/rulehub/rulehub-ci-images/actions/workflows/build-publish-rulehub.yml)

Centralized CI container images used across RuleHub repositories. Provides a shared base image and small overlays per repo domain.

- Base: `ghcr.io/rulehub/ci-base`
  - Common tooling: Python 3.12, Node 20, git, jq, yq, syft, cosign, oras, non-root user.
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

### Local vulnerability scan (OS-only)

You can replicate the CI vulnerability gate locally focusing on OS packages only (same config used in CI).

Prereqs (macOS):

- brew install syft grype

Run scans after building images locally (scan requires images to exist locally; no implicit pulls):

- make vuln-scan-os-base # scans ghcr.io/rulehub/ci-base:${BASE_REF}
- make vuln-scan-os-policy # scans ghcr.io/rulehub/ci-policy:${POLICY_REF}
- make vuln-scan-os-charts # scans ghcr.io/rulehub/ci-charts:${CHARTS_REF}
- make vuln-scan-os-frontend # scans ghcr.io/rulehub/ci-frontend:${FRONTEND_REF}

Or scan an arbitrary local/remote image:

- make vuln-scan-os IMG=ci-base:localtest

Details:

- Uses `.github/syft-os.yaml` to generate an OS-only SBOM and `.github/grype-os.yaml` to restrict matchers to OS packages.
- SBOMs are written per image under `logs/` as `sbom-os.<image_triple>.syft.json` and `sbom-os.<image_triple>.syft.os-only.json`.
- Fails the target on CRITICAL vulns (only-fixed) and adds CPEs if missing to improve matching.

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
