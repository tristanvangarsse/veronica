#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="${1:-$ROOT/.build/release/Veronica.app}"
IDENTITY="${DEVELOPER_ID_APPLICATION:-}"
PROFILE="${NOTARYTOOL_PROFILE:-}"

if [[ "$(uname -s)" != "Darwin" ]]; then echo "macOS required" >&2; exit 2; fi
if [[ -z "$IDENTITY" ]]; then echo "Set DEVELOPER_ID_APPLICATION to your Developer ID Application identity." >&2; exit 2; fi
if [[ -z "$PROFILE" ]]; then echo "Set NOTARYTOOL_PROFILE to a keychain profile created with xcrun notarytool store-credentials." >&2; exit 2; fi
if [[ ! -d "$APP" ]]; then echo "App not found: $APP" >&2; exit 2; fi

codesign --force --deep --options runtime --timestamp --sign "$IDENTITY" "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"
ZIP="${APP%.app}-notarize.zip"
ditto -c -k --keepParent "$APP" "$ZIP"
xcrun notarytool submit "$ZIP" --keychain-profile "$PROFILE" --wait
xcrun stapler staple "$APP"
spctl --assess --type execute --verbose=2 "$APP"
rm -f "$ZIP"
echo "Signed and notarized: $APP"
