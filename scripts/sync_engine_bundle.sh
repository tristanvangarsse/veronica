#!/bin/sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
DEST="$ROOT/macos/Veronica/Resources/Engine"
mkdir -p "$DEST"
cp "$ROOT/veronica.py" "$DEST/veronica.py"
cp "$ROOT/media_maintenance.py" "$DEST/media_maintenance.py"
cp "$ROOT/media_audit.py" "$DEST/media_audit.py"
cp "$ROOT/preset-720P.json" "$DEST/preset-720P.json"
echo "Veronica engine bundle synchronized."
