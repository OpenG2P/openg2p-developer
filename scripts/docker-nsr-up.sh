#!/usr/bin/env bash
# Docker-only National Social Registry: infra + IAM + AWE + NSR services + seed.
# Does NOT start Farmer.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/lib/docker-registry.sh"

docker_registry_resolve_compose
docker_registry_compose_files
docker_registry_prepare_env nsr
docker_registry_up_variant nsr
