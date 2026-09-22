#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DERIVED="$ROOT/.build/DerivedData"
EXPORT="$ROOT/.build/release"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "This script must be run on macOS." >&2
  exit 2
fi
command -v xcodegen >/dev/null || { echo "xcodegen is required" >&2; exit 2; }

cd "$ROOT/macos"
xcodegen generate
rm -rf "$DERIVED" "$EXPORT"
mkdir -p "$EXPORT"
xcodebuild \
  -project Veronica.xcodeproj \
  -scheme Veronica \
  -configuration Release \
  -derivedDataPath "$DERIVED" \
  CODE_SIGNING_ALLOWED=NO \
  build
cp -R "$DERIVED/Build/Products/Release/Veronica.app" "$EXPORT/Veronica.app"

echo "Local unsigned app: $EXPORT/Veronica.app"

if command -v hdiutil >/dev/null; then
  rm -f "$EXPORT/Veronica-local.dmg"
  hdiutil create -volname Veronica -srcfolder "$EXPORT/Veronica.app" -ov -format UDZO "$EXPORT/Veronica-local.dmg" >/dev/null
  echo "Local unsigned DMG: $EXPORT/Veronica-local.dmg"
fi
