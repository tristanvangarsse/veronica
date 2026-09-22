#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
fail=0
for p in \
  "$ROOT/macos/Veronica/Resources/VeronicaEngine/veronica-engine" \
  "$ROOT/macos/Veronica/Resources/Tools/bin/ffmpeg" \
  "$ROOT/macos/Veronica/Resources/Tools/bin/ffprobe" \
  "$ROOT/macos/Veronica/Resources/Tools/bin/HandBrakeCLI"; do
  if [[ ! -x "$p" ]]; then echo "MISSING: $p"; fail=1; else echo "OK: $p"; fi
done
if [[ $fail -ne 0 ]]; then
  echo "Release bundle is not self-contained yet. Development builds can still run using installed dependencies." >&2
  exit 2
fi
echo "Self-contained resource set present. Signing/notarization checks are still required for public release."
