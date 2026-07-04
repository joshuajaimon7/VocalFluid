#!/bin/bash
# Builds FlowLocal.app from the SPM release build.
#
# Usage:
#   ./scripts/make_app.sh                    # ad-hoc signed (local use)
#   IDENTITY="Developer ID Application: …" ./scripts/make_app.sh
set -euo pipefail

cd "$(dirname "$0")/.."

echo "==> Building (release)…"
swift build -c release

APP="build/FlowLocal.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp .build/release/FlowLocal "$APP/Contents/MacOS/FlowLocal"
cp Resources/Info.plist "$APP/Contents/Info.plist"

# Hardened runtime + entitlements (audio input).
# Prefer a real signing identity: ad-hoc signatures change on every rebuild,
# which makes macOS TCC silently revoke Accessibility/Microphone grants.
if [ -z "${IDENTITY:-}" ]; then
  IDENTITY=$(security find-identity -v -p codesigning 2>/dev/null \
    | awk -F'"' '/Apple Development|Developer ID Application/ {print $2; exit}')
  IDENTITY="${IDENTITY:--}"
fi
echo "==> Signing with identity: $IDENTITY"
codesign --force --options runtime \
  --entitlements Resources/FlowLocal.entitlements \
  --sign "$IDENTITY" "$APP"

echo "==> Done: $APP"
echo "    Move it to /Applications if you like, then launch it."
echo "    First run: grant Microphone + Accessibility when prompted."
