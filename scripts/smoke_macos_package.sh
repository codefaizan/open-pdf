#!/usr/bin/env bash
# Clean-machine smoke checks for a built macOS Open PDF package (Ticket 9).
# Exercises offline conversion via the embedded helper; documents Gatekeeper UI checks.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

usage() {
  cat <<'EOF'
Usage: smoke_macos_package.sh <Open PDF.app|Open-PDF-*.dmg>

Checks:
  - package inventory (app, PDF engine frameworks, worker, OCR, notices)
  - helper resolves from the installed layout
  - offline conversion (network disabled for the worker process)
  - paths with spaces and non-English characters
  - cancel leaves no complete workbook
  - Gatekeeper assessment hints (spctl) when signed

Full GUI navigate/search/uninstall still requires a clean Mac manual pass;
this script covers the automatable packaging smoke seam.
EOF
}

if [[ $# -lt 1 ]]; then
  usage >&2
  exit 2
fi

INPUT=$1
WORK="$(mktemp -d /tmp/open-pdf-smoke.XXXXXX)"
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

APP=""
if [[ "$INPUT" == *.dmg ]]; then
  ATTACH_OUT="$(hdiutil attach -nobrowse -readonly "$INPUT")"
  MOUNT="$(echo "$ATTACH_OUT" | awk '/\/Volumes\// {print $3; exit}')"
  if [[ -z "$MOUNT" ]]; then
    echo "Failed to mount DMG" >&2
    exit 1
  fi
  SRC_APP="$(find "$MOUNT" -maxdepth 1 -name '*.app' | head -n 1)"
  cp -R "$SRC_APP" "$WORK/Open PDF.app"
  hdiutil detach "$MOUNT" >/dev/null
  APP="$WORK/Open PDF.app"
elif [[ "$INPUT" == *.app ]]; then
  cp -R "$INPUT" "$WORK/Open PDF.app"
  APP="$WORK/Open PDF.app"
else
  echo "Expected .app or .dmg" >&2
  exit 2
fi

python3 "$ROOT/scripts/verify_macos_package.py" "$APP"

WORKER="$APP/Contents/Resources/worker/open_pdf_worker/open_pdf_worker"
TESSERACT="$APP/Contents/Resources/worker/open_pdf_worker/tesseract"
if ! "$TESSERACT" --version >/dev/null 2>&1; then
  echo "bundled tesseract failed to run" >&2
  exit 1
fi

echo "==> Offline conversion with spaced / unicode paths"
PDF_DIR="$WORK/docs with spaces/Документы"
mkdir -p "$PDF_DIR"
SAMPLE="$ROOT/corpus/ruled_table.pdf"
PDF="$PDF_DIR/sample report.pdf"
cp "$SAMPLE" "$PDF"
OUT="$PDF_DIR/output workbook.xlsx"

run_worker_job() {
  local input_pdf=$1
  local output_xlsx=$2
  local pages=${3:-}
  python3 - "$WORKER" "$input_pdf" "$output_xlsx" "$pages" <<'PY'
import json, subprocess, sys, os
from pathlib import Path

worker, pdf, out, pages = sys.argv[1:5]
env = os.environ.copy()
env["TESSERACT_CMD"] = str(Path(worker).parent / "tesseract")
for key in list(env):
    if key.lower().endswith("_proxy") or key in {"http_proxy", "https_proxy", "ALL_PROXY"}:
        env.pop(key, None)
env["PATH"] = "/usr/bin:/bin"

proc = subprocess.Popen(
    [worker],
    stdin=subprocess.PIPE,
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
    text=True,
    env=env,
)
assert proc.stdin and proc.stdout

def send(obj):
    proc.stdin.write(json.dumps(obj) + "\n")
    proc.stdin.flush()

def read():
    line = proc.stdout.readline()
    if not line:
        raise SystemExit(f"worker closed stdout; stderr={proc.stderr.read()}")
    return json.loads(line)

send({"type": "handshake", "protocol_version": "1.0"})
assert read()["type"] == "handshake_ack"
payload = {
    "type": "convert",
    "request_id": "smoke",
    "input_pdf": pdf,
    "output_xlsx": out,
}
if pages:
    payload["pages"] = pages
send(payload)
terminal = None
while True:
    event = read()
    if event.get("type") in {"complete", "error"}:
        terminal = event
        break
proc.stdin.close()
proc.wait(timeout=60)
print(json.dumps(terminal))
PY
}

APP_BEFORE="$(find "$APP/Contents" -type f | wc -l | tr -d ' ')"

terminal="$(run_worker_job "$PDF" "$OUT")"
echo "$terminal" | python3 -c 'import json,sys; e=json.load(sys.stdin); assert e["type"]=="complete", e'
test -f "$OUT"
APP_AFTER="$(find "$APP/Contents" -type f | wc -l | tr -d ' ')"
if [[ "$APP_AFTER" != "$APP_BEFORE" ]]; then
  echo "helper wrote into the application bundle ($APP_BEFORE -> $APP_AFTER files)" >&2
  exit 1
fi
echo "ok: offline conversion (helper did not write into .app)"

echo "==> Offline OCR conversion (bundled tesseract, no host PATH)"
OCR_PDF="$PDF_DIR/clean scan.pdf"
OCR_OUT="$PDF_DIR/ocr workbook.xlsx"
cp "$ROOT/corpus/clean_scan.pdf" "$OCR_PDF"
terminal="$(run_worker_job "$OCR_PDF" "$OCR_OUT")"
echo "$terminal" | python3 -c 'import json,sys; e=json.load(sys.stdin); assert e["type"]=="complete", e'
test -f "$OCR_OUT"
echo "ok: offline OCR conversion"

echo "==> Recover from invalid page range, then convert again"
BAD_OUT="$PDF_DIR/bad range.xlsx"
terminal="$(run_worker_job "$PDF" "$BAD_OUT" "9999")"
echo "$terminal" | python3 -c 'import json,sys; e=json.load(sys.stdin); assert e["type"]=="error", e'
test ! -f "$BAD_OUT"
RECOVER_OUT="$PDF_DIR/recovered.xlsx"
terminal="$(run_worker_job "$PDF" "$RECOVER_OUT")"
echo "$terminal" | python3 -c 'import json,sys; e=json.load(sys.stdin); assert e["type"]=="complete", e'
test -f "$RECOVER_OUT"
echo "ok: failure recovery"

echo "==> Cancel leaves no complete workbook"
CANCEL_PDF="$PDF_DIR/multi page.pdf"
cp "$ROOT/corpus/multi_page_table.pdf" "$CANCEL_PDF"
CANCEL_OUT="$PDF_DIR/cancelled.xlsx"
python3 - "$WORKER" "$CANCEL_PDF" "$CANCEL_OUT" <<'PY'
import json, subprocess, sys, os, time
from pathlib import Path

worker, pdf, out = sys.argv[1:4]
env = os.environ.copy()
env["TESSERACT_CMD"] = str(Path(worker).parent / "tesseract")
env["PATH"] = "/usr/bin:/bin"
proc = subprocess.Popen(
    [worker],
    stdin=subprocess.PIPE,
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
    text=True,
    env=env,
)
assert proc.stdin and proc.stdout

def send(obj):
    proc.stdin.write(json.dumps(obj) + "\n")
    proc.stdin.flush()

def read():
    line = proc.stdout.readline()
    if not line:
        return None
    return json.loads(line)

send({"type": "handshake", "protocol_version": "1.0"})
assert read()["type"] == "handshake_ack"
send({
    "type": "convert",
    "request_id": "smoke-cancel",
    "input_pdf": pdf,
    "output_xlsx": out,
})
while True:
    event = read()
    if event is None:
        raise SystemExit("worker exited before progress")
    if event.get("type") == "progress":
        send({"type": "cancel", "request_id": "smoke-cancel"})
        break
    if event.get("type") in {"complete", "error"}:
        raise SystemExit(f"finished before cancel: {event}")

terminal = None
deadline = time.time() + 60
while time.time() < deadline:
    event = read()
    if event is None:
        break
    if event.get("type") == "error" and event.get("code") == "CANCELLED":
        terminal = event
        break
    if event.get("type") == "complete":
        raise SystemExit("cancel raced with completion")
proc.stdin.close()
try:
    proc.wait(timeout=30)
except subprocess.TimeoutExpired:
    proc.kill()
if Path(out).is_file():
    raise SystemExit("cancel left a workbook that could be mistaken for success")
print("ok: cancel cleanup", terminal)
PY

echo "==> Gatekeeper assessment (informational if unsigned)"
if spctl --assess --type execute --verbose=4 "$APP" 2>&1; then
  echo "ok: spctl accepted execute assessment"
else
  echo "note: spctl did not accept the app (expected for unsigned/local builds)."
  echo "      A Developer ID + notarized artifact should pass Gatekeeper on a clean Mac."
fi

echo "==> Manual clean-Mac checklist (GUI)"
cat <<'EOF'
After copying Open PDF.app to /Applications on a clean supported Mac:
  [ ] Launch Open PDF
  [ ] Open a PDF (including a path with spaces / non-English characters)
  [ ] Navigate with thumbnails / page controls and search text
  [ ] Convert to Excel, observe progress, open/reveal the workbook
  [ ] Cancel an in-flight conversion
  [ ] Recover from a forced failure (e.g. invalid page range) and convert again
  [ ] Disable network (Airplane Mode) and repeat open + convert
  [ ] Quit and remove the application (Trash / delete .app)
  [ ] Gatekeeper: open a notarized DMG without right-click bypass warnings
EOF

echo "smoke_macos_package: automatable checks passed"
