#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/lib/registry-variant.sh"

VARIANT="${VARIANT:-farmer-registry}"
registry_variant_paths "$VARIANT"
registry_variant_db_settings "$VARIANT"
registry_variant_export_psql

# Prefer shared post-seed path (enums + history) used by Docker as well.
exec bash "${ROOT_DIR}/scripts/farmer-post-seed.sh"
