#!/usr/bin/env bash
# Resume Farmer Docker stack after a failed make docker-farmer-up.
# Does NOT tear down or rebuild from scratch — starts missing services + seeds.
# Optional: RESET_DBS=1 make docker-farmer-continue  (drop DBs, remigrate, seed)
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/lib/docker-registry.sh"

docker_registry_resolve_compose
docker_registry_compose_files
docker_registry_prepare_env farmer
docker_registry_continue_variant farmer
