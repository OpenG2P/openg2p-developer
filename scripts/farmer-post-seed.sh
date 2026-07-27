#!/usr/bin/env bash
# Post-process Farmer Registry sample seed:
#   1) normalize legacy enums / lookup codes (live + history + CR payloads)
#   2) backfill baseline register history rows
#
# Works against Docker Compose Postgres or native PG via PG* env vars.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

PGHOST="${PGHOST:-localhost}"
PGPORT="${PGPORT:-5433}"
PGDATABASE="${PGDATABASE:-farmer_registry_db}"
PGUSER="${PGUSER:-postgres}"
PGPASSWORD="${PGPASSWORD:-postgres}"
export PGHOST PGPORT PGDATABASE PGUSER PGPASSWORD

run_python_scripts() {
  if python3 -c 'import psycopg2' >/dev/null 2>&1; then
    python3 "${ROOT_DIR}/scripts/fix-farmer-registry-seeded-enums.py"
    python3 "${ROOT_DIR}/scripts/seed-farmer-registry-initial-history.py"
    return
  fi

  local network
  network="$(docker inspect openg2p-postgres --format '{{range $k,$v := .NetworkSettings.Networks}}{{$k}}{{end}}' 2>/dev/null | head -1)"
  if [[ -z "$network" ]]; then
    echo "[farmer-post-seed] psycopg2 missing and could not resolve postgres network" >&2
    exit 1
  fi

  docker run --rm \
    --network "$network" \
    -v "${ROOT_DIR}/scripts:/scripts:ro" \
    -e PGHOST=postgres \
    -e PGPORT=5432 \
    -e "PGDATABASE=${PGDATABASE}" \
    -e "PGUSER=${PGUSER}" \
    -e "PGPASSWORD=${PGPASSWORD}" \
    python:3.12-slim-bookworm \
    bash -lc 'pip install -q psycopg2-binary >/dev/null && python /scripts/fix-farmer-registry-seeded-enums.py && python /scripts/seed-farmer-registry-initial-history.py'
}

echo "[farmer-post-seed] Normalizing enums + backfilling register history ..."
run_python_scripts
echo "[farmer-post-seed] Done."
