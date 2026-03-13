#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ROOT_DIR}/.env"
SQL_FILE="${ROOT_DIR}/sql/executive_milestones.sql"

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "Missing ${ENV_FILE}. Copy .env.example to .env first." >&2
  exit 1
fi

pre_output_format="${OUTPUT_FORMAT:-}"
# shellcheck disable=SC1090
source "${ENV_FILE}"

customer_id="${1:-${CUSTOMER_ID:-}}"
facility_id="${2:-${FACILITY_ID:-}}"
format="${pre_output_format:-${OUTPUT_FORMAT:-aligned}}"

export PGPASSWORD="${PGPASSWORD:-}"

psql_opts=(
  -h "${PGHOST}"
  -p "${PGPORT}"
  -U "${PGUSER}"
  -d "${PGDATABASE}"
  -v ON_ERROR_STOP=1
  -v customer_id="${customer_id}"
  -v facility_id="${facility_id}"
  -f "${SQL_FILE}"
)

case "${format}" in
  csv)
    psql_opts+=(--csv)
    ;;
  unaligned)
    psql_opts+=(-A -t)
    ;;
  aligned)
    ;;
  *)
    echo "Unknown OUTPUT_FORMAT='${format}'. Use aligned|csv|unaligned" >&2
    exit 1
    ;;
esac

psql "${psql_opts[@]}"
