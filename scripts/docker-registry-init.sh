#!/usr/bin/env bash
# Deprecated: seeding is included in make docker-farmer-up / make docker-nsr-up.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

echo "Seeding is now part of each variant up command."
echo "  Farmer only:  make docker-farmer-up"
echo "  NSR only:     make docker-nsr-up"
echo "  Both:         make docker-registry-up"
echo
echo "Re-running seed for both variants ..."
bash "${ROOT_DIR}/scripts/docker-farmer-up.sh"
bash "${ROOT_DIR}/scripts/docker-nsr-up.sh"
