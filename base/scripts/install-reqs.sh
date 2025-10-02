#!/usr/bin/env bash
set -euo pipefail

PY=python3.11
if ! command -v "$PY" >/dev/null 2>&1; then PY=python3; fi

# install-reqs.sh
# Copy this into a Docker build context and run it to install python
# requirements files that were previously copied to /tmp/requirements*.txt

echo "[install-reqs] Using interpreter: $PY"
"$PY" -m pip install --no-cache-dir -U pip

if [ -f /tmp/requirements.lock ]; then
  echo "[install-reqs] Installing /tmp/requirements.lock"
  "$PY" -m pip install --no-cache-dir -r /tmp/requirements.lock
elif [ -f /tmp/requirements.txt ]; then
  echo "[install-reqs] Installing /tmp/requirements.txt"
  "$PY" -m pip install --no-cache-dir -r /tmp/requirements.txt
else
  echo "[install-reqs] No requirements or lock file found"
fi

if [ -f /tmp/requirements-dev.lock ]; then
  echo "[install-reqs] Installing /tmp/requirements-dev.lock"
  "$PY" -m pip install --no-cache-dir -r /tmp/requirements-dev.lock
elif [ -f /tmp/requirements-dev.txt ]; then
  echo "[install-reqs] Installing /tmp/requirements-dev.txt"
  "$PY" -m pip install --no-cache-dir -r /tmp/requirements-dev.txt
fi

rm -f /tmp/requirements* || true
