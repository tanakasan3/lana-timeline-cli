#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ROOT_DIR}/.env"

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "Missing ${ENV_FILE}. Copy .env.example to .env first." >&2
  exit 1
fi

# shellcheck disable=SC1090
source "${ENV_FILE}"

export PGPASSWORD="${PGPASSWORD:-}"

echo "Testing connection to ${PGUSER}@${PGHOST}:${PGPORT}/${PGDATABASE} ..."
psql \
  -h "${PGHOST}" \
  -p "${PGPORT}" \
  -U "${PGUSER}" \
  -d "${PGDATABASE}" \
  -v ON_ERROR_STOP=1 \
  -c "SELECT current_database() AS db, current_user AS db_user, now() AS db_time, version();" \
  -c "SELECT 1 AS ok;"

echo "Connection OK ✅"
