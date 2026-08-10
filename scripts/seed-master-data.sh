#!/usr/bin/env bash
# Seed Master Data geo/codelists from an openg2p-data country pack (preferred),
# falling back to registry-platform legacy geo.csv loader when packs are absent.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/lib/registry-variant.sh"

VARIANT="${VARIANT:-${1:-farmer-registry}}"
registry_variant_validate "$VARIANT"
registry_variant_paths "$VARIANT"
registry_variant_db_settings "$VARIANT"

OPENG2P_DATA_DIR="$(registry_variant_open_data_dir)"
COUNTRY_PACK="${MASTER_DATA_COUNTRY_PACK:-XKM}"
PACK_DIR="${OPENG2P_DATA_DIR}/packs/${COUNTRY_PACK}"
PACK_LOAD="${MASTER_DATA_PACK_LOAD:-geo,codelists}"
PACK_DOMAINS="${MASTER_DATA_PACK_DOMAINS:-}"

if [[ ! -d "$MASTER_DATA_SEED_DIR" || ! -f "${MASTER_DATA_SEED_DIR}/load_geo_pack.py" ]]; then
  echo "[master-data-seed] load_geo_pack.py not found; will try legacy geo.csv loader."
fi

registry_variant_export_master_psql

if [[ -d "$PACK_DIR" && -f "${PACK_DIR}/levels.json" && -f "${MASTER_DATA_SEED_DIR}/load_geo_pack.py" ]]; then
  if [[ ! -x "${MASTER_DATA_SEED_DIR}/venv/bin/python" ]]; then
    bash "${ROOT_DIR}/scripts/install-master-data.sh"
  fi
  echo "[master-data-seed] Loading country pack ${COUNTRY_PACK} into ${MASTER_DATA_DB_NAME} ..."
  echo "[master-data-seed]   pack=${PACK_DIR}"
  echo "[master-data-seed]   load=${PACK_LOAD} domains=${PACK_DOMAINS:-<none>}"
  (
    # shellcheck disable=SC1091
    source "${MASTER_DATA_SEED_DIR}/venv/bin/activate"
    export PGHOST="$MD_PGHOST" PGPORT="$MD_PGPORT" PGUSER="$MD_PGUSER" \
      PGPASSWORD="$MD_PGPASSWORD"
    python3 "${MASTER_DATA_SEED_DIR}/load_geo_pack.py" \
      --pack "$PACK_DIR" \
      --db "$MD_PGDATABASE" \
      --load "$PACK_LOAD" \
      --domains "$PACK_DOMAINS"
  )
  exit 0
fi

# Legacy fallback: registry-platform load_geo_data.py + geo/geo.csv
LEGACY_LOADER="${REGISTRY_ROOT}/docker/db-seed/load_geo_data.py"
GEO_CSV="${OPENG2P_DATA_DIR}/geo/geo.csv"
if [[ ! -f "$GEO_CSV" ]]; then
  echo "[master-data-seed] Preparing geo.csv from openg2p-data JSON (if needed) ..."
  if [[ -d "$OPENG2P_DATA_DIR" ]]; then
    python3 "${ROOT_DIR}/scripts/openg2p-data-geo-to-csv.py" "$OPENG2P_DATA_DIR" || true
  fi
fi

if [[ -f "$LEGACY_LOADER" && -f "$GEO_CSV" ]]; then
  echo "[master-data-seed] Country pack missing; using legacy geo.csv loader ..."
  registry_variant_ensure_master_data_geo_schema
  export OPENG2P_DATA_DIR
  if [[ -d "$DB_SEED_DIR" ]]; then
    registry_variant_ensure_db_seed_venv
    (
      # shellcheck disable=SC1091
      source "${DB_SEED_DIR}/venv/bin/activate"
      python3 "$LEGACY_LOADER"
    )
  else
    # shellcheck disable=SC1091
    source "${ROOT_DIR}/scripts/lib/ensure-psycopg2-python.sh"
    python_bin="$(ensure_psycopg2_python "$ROOT_DIR")"
    "$python_bin" "$LEGACY_LOADER"
  fi
  exit 0
fi

echo "[master-data-seed] No country pack at ${PACK_DIR} and no legacy geo.csv at ${GEO_CSV}." >&2
echo "Clone/update openg2p-data (make clone PROFILE=registry) or set OPENG2P_DATA_DIR." >&2
exit 1
