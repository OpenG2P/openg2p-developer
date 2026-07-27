#!/usr/bin/env bash
# Stop all OpenG2P Docker Compose services (infra, commons, farmer, nsr, pbms, bridge, spar).
# Volumes are kept. Use make docker-clean to also remove volumes.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/lib/docker-registry.sh"

docker_registry_resolve_compose
docker_registry_compose_files

if [[ -f .env ]]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi

docker_registry_down_all
