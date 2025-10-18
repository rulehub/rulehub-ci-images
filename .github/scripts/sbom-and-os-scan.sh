#!/usr/bin/env bash
set -euo pipefail

# sbom-and-os-scan.sh
# Args: <image-ref> (e.g., ghcr.io/org/ci-base-rulehub:v1.2.3)
# Outputs: sbom-<image>.spdx.json and sbom-<image>-os.syft.json/os-only.json

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <image-ref>" >&2
  exit 2
fi

IMG="$1"
BASE_NAME=$(echo "$IMG" | sed 's|.*/||; s|:|_|g')

syft "$IMG" -o spdx-json > "sbom-${BASE_NAME}.spdx.json"
syft -c .github/syft-os.yaml "$IMG" -o syft-json > "sbom-${BASE_NAME}-os.syft.json"

# Post-filter to OS-only to guard against tool drift
if command -v jq >/dev/null 2>&1; then
  jq '.artifacts |= map(select(.type=="apk" or .type=="deb" or .type=="rpm"))' \
    "sbom-${BASE_NAME}-os.syft.json" > "sbom-${BASE_NAME}-os.syft.os-only.json"
  SBOM_PATH="sbom-${BASE_NAME}-os.syft.os-only.json"
else
  SBOM_PATH="sbom-${BASE_NAME}-os.syft.json"
fi

GRYPE_CHECK_FOR_APP_UPDATE=false grype -c .github/grype-os.yaml sbom:"$SBOM_PATH" \
  --fail-on critical --only-fixed --add-cpes-if-none

echo "Generated: sbom-${BASE_NAME}.spdx.json"
