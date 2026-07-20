#!/usr/bin/env bash
# Build a distributable macOS Open PDF.app (+ optional DMG) with worker, OCR, notices.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT/app"
OUT_DIR="${OPEN_PDF_MACOS_OUT:-$ROOT/artifacts/macos}"
ARCH="$(uname -m)"
SKIP_SIGN=0
SKIP_DMG=0
SIGN_ARGS=()

usage() {
  cat <<'EOF'
Usage: package_macos.sh [--arch arm64|x86_64] [--skip-sign] [--skip-dmg] [--skip-notarize]

Builds the Flutter macOS release app, embeds the frozen conversion worker,
bundled Tesseract (+ dylibs), OCR models, and THIRD_PARTY_NOTICES.

Architecture-specific artifacts are produced for the host (or --arch when the
toolchain can target it). Universal binaries are optional and not required.

Signing / notarization use scripts/sign_and_notarize_macos.sh and environment
credentials only (never source control).
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --arch)
      ARCH=$2
      shift 2
      ;;
    --skip-sign) SKIP_SIGN=1; shift ;;
    --skip-dmg) SKIP_DMG=1; shift ;;
    --skip-notarize) SIGN_ARGS+=(--skip-notarize); shift ;;
    -h|--help) usage; exit 0 ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

HOST_ARCH="$(uname -m)"
if [[ "$ARCH" != "$HOST_ARCH" ]]; then
  echo "Requested arch $ARCH differs from host $HOST_ARCH." >&2
  echo "Build architecture-specific artifacts on matching hardware (or CI)." >&2
  exit 1
fi

case "$ARCH" in
  arm64|x86_64) ;;
  *)
    echo "Unsupported arch: $ARCH" >&2
    exit 1
    ;;
esac

export PATH="${FLUTTER_ROOT:-$HOME/.puro/envs/default/flutter}/bin:$PATH"
if ! command -v flutter >/dev/null 2>&1; then
  export PATH="$HOME/.puro/envs/stable/flutter/bin:$PATH"
fi
if ! command -v flutter >/dev/null 2>&1; then
  echo "flutter not found on PATH" >&2
  exit 1
fi

echo "==> Freezing conversion worker"
"$ROOT/scripts/freeze_worker.sh"

WORKER_DIST="$ROOT/worker/dist/open_pdf_worker"
if [[ ! -x "$WORKER_DIST/open_pdf_worker" ]]; then
  echo "Frozen worker missing at $WORKER_DIST" >&2
  exit 1
fi

TESSERACT_SRC="${OPEN_PDF_TESSERACT_BIN:-$(command -v tesseract || true)}"
if [[ -z "$TESSERACT_SRC" || ! -x "$TESSERACT_SRC" ]]; then
  echo "tesseract binary not found; set OPEN_PDF_TESSERACT_BIN" >&2
  exit 1
fi

echo "==> Building Flutter macOS release ($ARCH)"
mkdir -p "$OUT_DIR"
cd "$APP_DIR"
flutter pub get
# Host architecture determines the Flutter/Xcode slice; produce arch-tagged artifacts.
flutter build macos --release

BUILT_APP="$(find "$APP_DIR/build/macos/Build/Products/Release" -maxdepth 1 -name '*.app' | head -n 1)"
if [[ -z "$BUILT_APP" || ! -d "$BUILT_APP" ]]; then
  echo "Flutter release .app not found" >&2
  exit 1
fi

APP_NAME="Open PDF.app"
STAGE="$OUT_DIR/stage-$ARCH"
rm -rf "$STAGE"
mkdir -p "$STAGE"
cp -R "$BUILT_APP" "$STAGE/$APP_NAME"
APP="$STAGE/$APP_NAME"

echo "==> Embedding worker, OCR binary, and notices"
RESOURCES="$APP/Contents/Resources"
WORKER_DEST="$RESOURCES/worker/open_pdf_worker"
rm -rf "$RESOURCES/worker"
mkdir -p "$RESOURCES/worker"
cp -R "$WORKER_DIST" "$WORKER_DEST"

# Bundle tesseract next to the worker (see open_pdf_worker.ocr.find_tesseract_binary).
python3 "$ROOT/scripts/bundle_macho_deps.py" "$TESSERACT_SRC" "$WORKER_DEST"

cp "$ROOT/THIRD_PARTY_NOTICES" "$RESOURCES/THIRD_PARTY_NOTICES"

# Record architecture for inventory / support.
/usr/libexec/PlistBuddy -c "Add :OpenPDFArchitecture string $ARCH" "$APP/Contents/Info.plist" 2>/dev/null \
  || /usr/libexec/PlistBuddy -c "Set :OpenPDFArchitecture $ARCH" "$APP/Contents/Info.plist"

echo "==> Verifying package inventory"
python3 "$ROOT/scripts/verify_macos_package.py" "$APP"

create_dmg() {
  local app_path=$1
  local dmg_path=$2
  local stage
  stage="$(dirname "$dmg_path")/dmg-stage-$$"
  rm -rf "$stage" "$dmg_path"
  mkdir -p "$stage"
  cp -R "$app_path" "$stage/Open PDF.app"
  ln -s /Applications "$stage/Applications"
  hdiutil create -volname "Open PDF" -srcfolder "$stage" -ov -format UDZO "$dmg_path"
  rm -rf "$stage"
}

FINAL_APP="$OUT_DIR/Open-PDF-$ARCH.app"
rm -rf "$FINAL_APP"
cp -R "$APP" "$FINAL_APP"

if [[ "$SKIP_SIGN" -eq 0 ]]; then
  if [[ -z "${OPEN_PDF_CODESIGN_IDENTITY:-}" ]]; then
    echo "OPEN_PDF_CODESIGN_IDENTITY unset; producing unsigned package (use --skip-sign to silence)." >&2
    SKIP_SIGN=1
  fi
fi

DMG="$OUT_DIR/Open-PDF-$ARCH.dmg"

if [[ "$SKIP_SIGN" -eq 0 ]]; then
  echo "==> Signing application"
  # Sign the .app before DMG creation; notarize the DMG for Gatekeeper distribution.
  "$ROOT/scripts/sign_and_notarize_macos.sh" --skip-notarize "$FINAL_APP"
fi

if [[ "$SKIP_DMG" -eq 0 ]]; then
  echo "==> Creating DMG"
  create_dmg "$FINAL_APP" "$DMG"
fi

if [[ "$SKIP_SIGN" -eq 0 && "$SKIP_DMG" -eq 0 && -f "$DMG" ]]; then
  echo "==> Notarizing DMG"
  if [[ " ${SIGN_ARGS[*]} " == *" --skip-notarize "* ]]; then
    "$ROOT/scripts/sign_and_notarize_macos.sh" --skip-notarize "$DMG"
  else
    "$ROOT/scripts/sign_and_notarize_macos.sh" "$DMG"
  fi
fi

echo "macOS package ready:"
echo "  $FINAL_APP"
if [[ "$SKIP_DMG" -eq 0 ]]; then
  echo "  $DMG"
fi
if [[ "$SKIP_SIGN" -eq 0 && "$SKIP_DMG" -eq 0 ]]; then
  echo "Gatekeeper: open the notarized DMG on a clean Mac (spctl --assess --type open --context context:primary-signature \"$DMG\")."
fi