#!/usr/bin/env bash
# run.sh — wipe the Godot import cache and launch the Neuromancer Chiba slice.
#
# Fresh clones have no .godot/ cache (it's gitignored), and a stale cache after a
# pull can leave the import db pointing at old assets. This clears it, rebuilds
# the import, then runs the game from source.
#
# Usage:
#   ./run.sh                       # uses `godot` on PATH
#   GODOT=/path/to/godot ./run.sh  # or point at a specific binary
#   ./run.sh --editor              # open in the editor instead of running
set -euo pipefail

cd "$(dirname "$0")"

GODOT="${GODOT:-godot}"
if ! command -v "$GODOT" >/dev/null 2>&1; then
  echo "error: Godot not found. Install Godot 4.6, then either put it on PATH" >&2
  echo "       or run:  GODOT=/path/to/godot ./run.sh" >&2
  exit 1
fi

echo "==> Clearing Godot import cache (.godot/ + *.import)…"
rm -rf .godot
find . -name '*.import' -not -path './.git/*' -delete 2>/dev/null || true

echo "==> Rebuilding import cache…"
# A clean --import can exit non-zero even on success; the cache is built regardless.
"$GODOT" --headless --import || true

if [[ "${1:-}" == "--editor" || "${1:-}" == "-e" ]]; then
  echo "==> Opening in the Godot editor…"
  exec "$GODOT" --editor --path .
fi

echo "==> Launching Neuromancer…"
exec "$GODOT" --path .
