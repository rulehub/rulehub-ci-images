# charts/cache

Optional cache for pre-fetched Helm tarballs to make builds resilient/offline.

- Expected filename format: `helm-<HELM_VERSION>-linux-<arch>.tar.gz`
  - Example (amd64): `helm-v3.15.3-linux-amd64.tar.gz`
  - Example (arm64): `helm-v3.15.3-linux-arm64.tar.gz`
- During `charts/` image build, the Dockerfile copies this directory and, if a matching tarball is present, uses it instead of downloading from the network.

## Prefetch helper

You can prefetch the correct tarball via:

```bash
./hack/prefetch-helm.sh v3.15.3 amd64   # or arm64
```

This will store the tarball into `charts/cache/` so subsequent builds avoid network fetch.
