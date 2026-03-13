#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="${ROOT_DIR}/out"
mkdir -p "$OUT_DIR"

stamp="$(date -u +%Y%m%dT%H%M%SZ)"
timeline_csv="${OUT_DIR}/timeline_${stamp}.csv"
milestones_csv="${OUT_DIR}/milestones_${stamp}.csv"
html_out="${OUT_DIR}/explorer_${stamp}.html"

OUTPUT_FORMAT=csv "${ROOT_DIR}/scripts/run_timeline.sh" "${1:-}" "${2:-}" > "$timeline_csv"
OUTPUT_FORMAT=csv "${ROOT_DIR}/scripts/run_milestones.sh" "${1:-}" "${2:-}" > "$milestones_csv"
python3 "${ROOT_DIR}/scripts/build_explorer.py" "$timeline_csv" "$milestones_csv" "$html_out" >/dev/null
cp "$html_out" "${OUT_DIR}/index.html"

echo "timeline_csv=$timeline_csv"
echo "milestones_csv=$milestones_csv"
echo "explorer_html=$html_out"
echo "explorer_latest=${OUT_DIR}/index.html"
