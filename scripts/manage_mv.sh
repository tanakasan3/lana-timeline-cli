#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ROOT_DIR}/.env"
CREATE_SQL="${ROOT_DIR}/sql/create_timeline_mv.sql"

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "Missing ${ENV_FILE}. Copy .env.example to .env first." >&2
  exit 1
fi

# shellcheck disable=SC1090
source "${ENV_FILE}"
export PGPASSWORD="${PGPASSWORD:-}"

action="${1:-refresh}"

case "$action" in
  create)
    psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$PGDATABASE" -v ON_ERROR_STOP=1 -f "$CREATE_SQL"
    ;;
  refresh)
    psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$PGDATABASE" -v ON_ERROR_STOP=1 -c "REFRESH MATERIALIZED VIEW core_customer_loan_timeline_mv;"
    ;;
  drop)
    psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$PGDATABASE" -v ON_ERROR_STOP=1 -c "DROP MATERIALIZED VIEW IF EXISTS core_customer_loan_timeline_mv;"
    ;;
  *)
    echo "Usage: $0 {create|refresh|drop}" >&2
    exit 1
    ;;
esac
