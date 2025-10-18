# ci-checksums

Pinned SHA256 checksums for third-party CLI binaries baked into RuleHub CI images.

Purpose:

- Supply chain integrity: verify downloaded release artifacts (OPA, Kyverno, etc.).
- Determinism: fail fast on upstream tampering or silent release mutation.

Layout:

```text
ci-checksums/
  opa/<version>/linux_amd64_static.sha256
  kyverno/<version>/kyverno-cli_v<version>_linux_x86_64.tar.gz.sha256
  (Optionally *_arm64 variants as we expand multi-arch)
```

Each file contains the raw SHA256 hash followed by two spaces and the filename
expected (coreutils sha256sum format). Example:

```text
<SHA256>  opa_linux_amd64_static
```

Fetching / updating:

Run the helper script:

```bash
hack/fetch-checksums.sh --opa 1.8.0 --kyverno 1.15.1
```

This will (re)generate missing checksum files without overwriting existing ones (unless --force).

Policy:

- All new CLI versions MUST land with their checksum files in the same PR.
- Dockerfiles should pass the hash via build-arg and enforce `sha256sum -c -`.
