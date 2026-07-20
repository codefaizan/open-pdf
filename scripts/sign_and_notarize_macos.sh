#!/usr/bin/env bash
# Nested codesign + notarize + staple for Open PDF.app / .dmg.
# Credentials come only from the environment / notarytool keychain profile.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENTITLEMENTS="${OPEN_PDF_ENTITLEMENTS:-$ROOT/app/macos/Runner/Release.entitlements}"

usage() {
  cat <<'EOF'
Usage: sign_and_notarize_macos.sh [--skip-notarize] <Open PDF.app|Open PDF.dmg>

Required environment:
  OPEN_PDF_CODESIGN_IDENTITY   e.g. "Developer ID Application: Example Inc (TEAMID)"

Notarization (unless --skip-notarize):
  OPEN_PDF_NOTARY_PROFILE      notarytool keychain profile name
    OR
  OPEN_PDF_NOTARY_APPLE_ID
  OPEN_PDF_NOTARY_TEAM_ID
  OPEN_PDF_NOTARY_PASSWORD     app-specific password / @keychain reference

Prefer notarizing the .dmg (Gatekeeper distribution). Signing an .app
first, then building and notarizing the DMG, is the supported release path.

Never commit credential values to this repository.
EOF
}

SKIP_NOTARIZE=0
TARGET=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-notarize) SKIP_NOTARIZE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *)
      if [[ -n "$TARGET" ]]; then
        echo "Unexpected argument: $1" >&2
        usage >&2
        exit 2
      fi
      TARGET=$1
      shift
      ;;
  esac
done

if [[ -z "$TARGET" ]]; then
  usage >&2
  exit 2
fi

if [[ -z "${OPEN_PDF_CODESIGN_IDENTITY:-}" ]]; then
  echo "OPEN_PDF_CODESIGN_IDENTITY is required (Developer ID Application …)." >&2
  exit 2
fi

if [[ ! -f "$ENTITLEMENTS" ]]; then
  echo "Entitlements file not found: $ENTITLEMENTS" >&2
  exit 1
fi

sign_path() {
  local path=$1
  codesign --force --options runtime --timestamp \
    --entitlements "$ENTITLEMENTS" \
    --sign "$OPEN_PDF_CODESIGN_IDENTITY" \
    "$path"
}

sign_app_nested() {
  local app=$1
  echo "Signing nested Mach-O binaries inside $app"
  while IFS= read -r -d '' binary; do
    sign_path "$binary"
  done < <(find "$app/Contents" -type f \( -perm -111 -o -name '*.dylib' -o -name '*.so' \) -print0)

  while IFS= read -r -d '' bundle; do
    sign_path "$bundle"
  done < <(find "$app/Contents" -type d \( -name '*.framework' -o -name '*.appex' -o -name '*.xpc' \) -print0)

  echo "Signing app bundle $app"
  codesign --force --options runtime --timestamp \
    --entitlements "$ENTITLEMENTS" \
    --sign "$OPEN_PDF_CODESIGN_IDENTITY" \
    "$app"

  codesign --verify --deep --strict --verbose=2 "$app"
}

notarize_and_staple() {
  local artifact=$1
  if [[ -n "${OPEN_PDF_NOTARY_PROFILE:-}" ]]; then
    xcrun notarytool submit "$artifact" --keychain-profile "$OPEN_PDF_NOTARY_PROFILE" --wait
  else
    if [[ -z "${OPEN_PDF_NOTARY_APPLE_ID:-}" || -z "${OPEN_PDF_NOTARY_TEAM_ID:-}" || -z "${OPEN_PDF_NOTARY_PASSWORD:-}" ]]; then
      echo "Set OPEN_PDF_NOTARY_PROFILE or OPEN_PDF_NOTARY_APPLE_ID/TEAM_ID/PASSWORD." >&2
      exit 2
    fi
    xcrun notarytool submit "$artifact" \
      --apple-id "$OPEN_PDF_NOTARY_APPLE_ID" \
      --team-id "$OPEN_PDF_NOTARY_TEAM_ID" \
      --password "$OPEN_PDF_NOTARY_PASSWORD" \
      --wait
  fi
  xcrun stapler staple "$artifact"
  xcrun stapler validate "$artifact"
}

TARGET="$(cd "$(dirname "$TARGET")" && pwd)/$(basename "$TARGET")"

if [[ "$TARGET" == *.app ]]; then
  sign_app_nested "$TARGET"
  if [[ "$SKIP_NOTARIZE" -eq 0 ]]; then
    ZIP="${TARGET%.app}-notarize.zip"
    rm -f "$ZIP"
    ditto -c -k --keepParent "$TARGET" "$ZIP"
    # Notary ticket is tied to the app's CDHash; staple the .app after submit.
    if [[ -n "${OPEN_PDF_NOTARY_PROFILE:-}" ]]; then
      xcrun notarytool submit "$ZIP" --keychain-profile "$OPEN_PDF_NOTARY_PROFILE" --wait
    else
      xcrun notarytool submit "$ZIP" \
        --apple-id "$OPEN_PDF_NOTARY_APPLE_ID" \
        --team-id "$OPEN_PDF_NOTARY_TEAM_ID" \
        --password "$OPEN_PDF_NOTARY_PASSWORD" \
        --wait
    fi
    xcrun stapler staple "$TARGET"
    xcrun stapler validate "$TARGET"
    rm -f "$ZIP"
  fi
elif [[ "$TARGET" == *.dmg ]]; then
  if [[ "$SKIP_NOTARIZE" -eq 0 ]]; then
    notarize_and_staple "$TARGET"
  else
    codesign --force --timestamp --sign "$OPEN_PDF_CODESIGN_IDENTITY" "$TARGET"
  fi
else
  echo "Unsupported target (expected .app or .dmg): $TARGET" >&2
  exit 2
fi

echo "Signing pipeline complete for $TARGET"
