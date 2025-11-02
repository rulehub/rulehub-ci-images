#!/usr/bin/env bash
set -euo pipefail

# Prefer the interpreter version that matches the lock generation (Python 3.13),
# then fall back sensibly. Using a mismatched lower version (e.g., 3.11) can
# cause pip to resolve extra transitive deps (like typing-extensions) that are
# not present with hashes in the 3.13-generated lock file, breaking hash mode.
if command -v python3.13 >/dev/null 2>&1; then
  PY=python3.13
elif command -v python3.12 >/dev/null 2>&1; then
  PY=python3.12
elif command -v python3 >/dev/null 2>&1; then
  PY=python3
else
  PY=python3.11
fi

# install-reqs.sh
# Copy this into a Docker build context and run it to install python
# requirements files that were previously copied to /tmp/requirements*.txt

echo "[install-reqs] Using interpreter: $PY"
# Do not upgrade system pip inside Debian/Ubuntu images to avoid uninstalling
# the distro-managed pip package (which lacks RECORD metadata and causes errors).
# Use the existing pip to install project requirements globally.

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
  echo "[install-reqs] Installing /tmp/requirements-dev.lock into a dedicated venv to avoid system pip conflicts"
  VENV_DIR=/opt/rulehub-venv
  "$PY" -m venv "$VENV_DIR"
  # shellcheck disable=SC1091
  . "$VENV_DIR/bin/activate"
  python -m pip install --no-cache-dir -r /tmp/requirements-dev.lock
  # keep venv on disk; do not modify PATH here (base image already provides tool venv)
elif [ -f /tmp/requirements-dev.txt ]; then
  echo "[install-reqs] Installing /tmp/requirements-dev.txt"
  "$PY" -m pip install --no-cache-dir -r /tmp/requirements-dev.txt
fi

rm -f /tmp/requirements* || true
