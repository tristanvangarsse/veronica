#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/macos/Veronica/Resources/Tools/bin"
mkdir -p "$OUT"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "This script must be run on macOS." >&2
  exit 2
fi

missing=0
for tool in ffmpeg ffprobe HandBrakeCLI; do
  src="$(command -v "$tool" || true)"
  if [[ -z "$src" ]]; then
    echo "Missing $tool. Install/provide it before staging release tools." >&2
    missing=1
    continue
  fi
  cp "$src" "$OUT/$tool"
  chmod 755 "$OUT/$tool"
  echo "Staged $tool from $src"
done
[[ $missing -eq 0 ]] || exit 2

# /usr/bin/file and /usr/bin/xattr are macOS system tools and are intentionally not redistributed.
# Homebrew executables can depend on libraries outside the app. Refuse to label the staged tools portable
# if otool shows non-system absolute dependencies. A release maintainer must replace such binaries with
# redistributable self-contained builds or bundle/sign their dependent libraries correctly.
problem=0
for tool in ffmpeg ffprobe HandBrakeCLI; do
  while IFS= read -r dep; do
    case "$dep" in
      /System/*|/usr/lib/*|@rpath/*|@loader_path/*|@executable_path/*) ;;
      *) echo "NON-PORTABLE dependency for $tool: $dep" >&2; problem=1 ;;
    esac
  done < <(otool -L "$OUT/$tool" | tail -n +2 | awk '{print $1}')
done
if [[ $problem -ne 0 ]]; then
  echo "Staged tools are suitable for local development but NOT yet for public distribution." >&2
  exit 3
fi

echo "Media tools passed portable dependency check. Review licenses before redistribution."
