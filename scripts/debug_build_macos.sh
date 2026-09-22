#!/bin/sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
LOG="/tmp/veronica-build.log"
cd "$ROOT"
./scripts/sync_engine_bundle.sh
cd macos
xcodegen generate >/dev/null
set +e
set -o pipefail
xcodebuild -project Veronica.xcodeproj -scheme Veronica -configuration Debug -destination 'platform=macOS' build 2>&1 | tee "$LOG"
STATUS=$?
set -e
printf '\n--- Veronica build log (last 120 lines) ---\n'
tail -120 "$LOG"
printf '\nFull log: %s\n' "$LOG"
exit "$STATUS"
