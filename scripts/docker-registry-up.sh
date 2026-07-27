#!/usr/bin/env bash
# Convenience: bring up both Farmer and NSR (each with its own seed).
# Prefer: make docker-farmer-up  OR  make docker-nsr-up
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

bash "${ROOT_DIR}/scripts/docker-farmer-up.sh"
bash "${ROOT_DIR}/scripts/docker-nsr-up.sh"
