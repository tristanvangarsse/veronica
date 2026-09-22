#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
command -v xcodegen >/dev/null || { echo "xcodegen is required" >&2; exit 2; }
cd "$ROOT/macos"
xcodegen generate
open Veronica.xcodeproj
