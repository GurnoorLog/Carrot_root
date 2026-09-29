#!/usr/bin/env bash
set -euo pipefail

GODOT="${GODOT:-/c/Users/tambe/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe}"
OUT="build/web"
ZIP="carrot-root-web.zip"

[ -f "$GODOT" ] || { echo "Godot not found at $GODOT"; exit 1; }

echo "Exporting web build..."
mkdir -p "$OUT"
"$GODOT" --headless --path . --export-release "Web" "$OUT/index.html" 2>&1 \
	| grep -viE "leaked|RID alloc|at: " || true

[ -f "$OUT/index.wasm" ] || { echo "Export failed: no wasm produced"; exit 1; }

rm -f "$OUT"/*.import

echo "Packaging $ZIP..."
rm -f "$ZIP"
python -c "import shutil; shutil.make_archive('carrot-root-web', 'zip', '$OUT')"

echo "Done: $ZIP ($(du -h "$ZIP" | cut -f1))"
echo "Upload this file on itch.io and tick 'This file will be played in the browser'."
