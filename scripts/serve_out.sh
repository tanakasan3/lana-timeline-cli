#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="${ROOT_DIR}/out"
PORT="${1:-8000}"

mkdir -p "$OUT_DIR"
cd "$OUT_DIR"
echo "Serving $OUT_DIR at http://127.0.0.1:${PORT}"
python3 -m http.server "$PORT"
