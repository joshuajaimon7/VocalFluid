#!/bin/bash
# Builds VocalFluid.app and packages it into a distribution DMG.
#
# Usage:
#   ./scripts/make_dmg.sh
set -euo pipefail

cd "$(dirname "$0")/.."

echo "==> Step 1: Building VocalFluid.app…"
./scripts/make_app.sh

APP="build/VocalFluid.app"
DMG_STAGING="build/dmg_staging"
DMG_OUTPUT="build/VocalFluid.dmg"

echo "==> Step 2: Preparing DMG staging folder…"
rm -rf "$DMG_STAGING" "$DMG_OUTPUT"
mkdir -p "$DMG_STAGING"

echo "==> Step 3: Copying application bundle…"
cp -R "$APP" "$DMG_STAGING/VocalFluid.app"

echo "==> Step 4: Creating /Applications drag-and-drop symlink…"
ln -s /Applications "$DMG_STAGING/Applications"

echo "==> Step 5: Generating compressed disk image (UDZO)…"
hdiutil create \
  -volname "VocalFluid" \
  -srcfolder "$DMG_STAGING" \
  -ov \
  -format UDZO \
  "$DMG_OUTPUT"

rm -rf "$DMG_STAGING"

echo "=========================================="
echo "  VocalFluid.dmg created successfully!"
echo "  Path: $DMG_OUTPUT"
echo "  Size: $(du -h "$DMG_OUTPUT" | cut -f1)"
echo "=========================================="
