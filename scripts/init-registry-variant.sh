#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VARIANT="${VARIANT:-${1:-}}"

VARIANT="$VARIANT" bash "${ROOT_DIR}/scripts/init-master-data.sh" "$VARIANT"
"${ROOT_DIR}/scripts/migrate-registry-db.sh" "$VARIANT"
if [[ "${LOAD_SAMPLE_DATA:-false}" == "true" && "${LOAD_GEO_DATA:-}" != "false" ]]; then
  LOAD_GEO_DATA=true
fi
LOAD_GEO_DATA="${LOAD_GEO_DATA:-false}" "${ROOT_DIR}/scripts/seed-registry-db.sh" "$VARIANT"

echo
echo "Registry variant ${VARIANT} is initialized (schema migrated + configuration seeded)."
echo "Optional demo data:"
echo "  LOAD_SAMPLE_DATA=true VARIANT=${VARIANT} make seed-registry"
