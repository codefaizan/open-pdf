#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKER_DIR="$ROOT/worker"
DIST_DIR="$WORKER_DIR/dist/open_pdf_worker"

cd "$WORKER_DIR"

if [[ ! -d .venv ]]; then
  python3 -m venv .venv
fi

# shellcheck disable=SC1091
source .venv/bin/activate

python -m pip install --upgrade pip >/dev/null
python -m pip install -e ".[dev]" "pyinstaller>=6.21.0" >/dev/null

pyinstaller --noconfirm open_pdf_worker.spec

if [[ ! -x "$DIST_DIR/open_pdf_worker" && ! -x "$DIST_DIR/open_pdf_worker.exe" ]]; then
  echo "Frozen worker executable not found in $DIST_DIR" >&2
  exit 1
fi

echo "Frozen worker ready at $DIST_DIR"
