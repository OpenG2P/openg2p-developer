#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/lib/registry-variant.sh"

VARIANT="${VARIANT:-${1:-national-social-registry}}"
registry_variant_validate "$VARIANT"
registry_variant_paths "$VARIANT"

if [[ ! -d "$DB_SEED_DIR" ]]; then
  echo "No db-seed directory at ${DB_SEED_DIR}; skipping (optional for custom extensions)." >&2
  exit 0
fi

# Farmer/NSR db-seed may ship without requirements.txt (deps come from the
# Docker image). Local native seed still needs a venv + psycopg2.
if [[ -f "${DB_SEED_DIR}/requirements.txt" ]]; then
  bash "${ROOT_DIR}/scripts/install-python-project.sh" "$DB_SEED_DIR"
else
  echo "No requirements.txt in ${DB_SEED_DIR}; creating minimal db-seed venv ..."
  PYTHON_BIN="${OPENG2P_PYTHON:-python3}"
  if [[ ! -d "${DB_SEED_DIR}/venv" ]]; then
    "${PYTHON_BIN}" -m venv "${DB_SEED_DIR}/venv"
  fi
  (
    # shellcheck disable=SC1091
    source "${DB_SEED_DIR}/venv/bin/activate"
    pip install --upgrade pip wheel
  )
fi

(
  # shellcheck disable=SC1091
  source "${DB_SEED_DIR}/venv/bin/activate"
  # Product Docker images install psycopg2 via apk; local dev needs a wheel.
  pip install 'psycopg2-binary>=2.9.12'
)

echo "db-seed Python environment ready for ${LABEL}."
