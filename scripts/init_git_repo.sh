#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
if [[ -d .git ]]; then
  echo "Git repository already initialized: $ROOT"
  exit 0
fi
git init
git add .
git commit -m "Initial Veronica source import"
echo "Git repository initialized at $ROOT"
echo "Create an empty GitHub repository, then add it with:"
echo "  git remote add origin git@github.com:YOUR_ACCOUNT/veronica.git"
echo "  git branch -M main"
echo "  git push -u origin main"
