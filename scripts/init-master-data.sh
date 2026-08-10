#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/lib/registry-variant.sh"

VARIANT="${VARIANT:-${1:-farmer-registry}}"
registry_variant_validate "$VARIANT"
registry_variant_paths "$VARIANT"
registry_variant_db_settings "$VARIANT"

"${ROOT_DIR}/scripts/infra-wait.sh"
"${ROOT_DIR}/scripts/generate-config.sh" >/dev/null

if [[ ! -d "$MASTER_DATA_API_DIR" ]]; then
  echo "Master Data API not found at ${MASTER_DATA_API_DIR}. Run: make clone" >&2
  exit 1
fi

if [[ ! -x "${MASTER_DATA_API_DIR}/venv/bin/python" ]]; then
  echo "Master Data venv missing. Run: make install-master-data" >&2
  exit 1
fi

ENV_FILE="${GENERATED_DIR}/master-data-api.env"
if [[ ! -f "$ENV_FILE" ]]; then
  echo "Missing ${ENV_FILE}. Run: make generate" >&2
  exit 1
fi

bash "${ROOT_DIR}/scripts/postgres-ensure-extension-databases.sh" "$VARIANT" || true

echo "Migrating Master Data schema into ${MASTER_DATA_DB_NAME} ..."
(
  cd "$MASTER_DATA_API_DIR"
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
  # shellcheck disable=SC1091
  source venv/bin/activate
  python -m openg2p_gen2_master_data.main migrate
)

MIGRATION_SQL="${MASTER_DATA_ROOT}/scripts/migrations/001_geo_pcode_boundaries.sql"
if [[ -f "$MIGRATION_SQL" ]]; then
  registry_variant_export_master_psql
  echo "[master-data] Applying ${MIGRATION_SQL} ..."
  PGHOST="$MD_PGHOST" PGPORT="$MD_PGPORT" PGUSER="$MD_PGUSER" \
    PGPASSWORD="$MD_PGPASSWORD" PGDATABASE="$MD_PGDATABASE" \
    psql -v ON_ERROR_STOP=1 -f "$MIGRATION_SQL"
fi

echo "Master Data initialized for ${LABEL} (${MASTER_DATA_DB_NAME})."
