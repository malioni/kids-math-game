#!/usr/bin/env bash
# Marks every SVG under assets/sprites/ as a scalable texture (DPITexture), then runs Godot's import.
# Godot imports a new SVG as a fixed-size texture, which turns soft when the window is stretched, unless
# an .import file says otherwise. This writes that file for any SVG that has none yet, and converts
# one that Godot already imported as a fixed-size texture. Run it after adding an SVG;
# tests/test_sprites.gd fails if one was missed.
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-/Applications/Godot-2.app/Contents/MacOS/Godot}"
find assets/sprites -name '*.svg' | while IFS= read -r svg; do
	if ! grep -qs 'type="DPITexture"' "$svg.import"; then
		printf '[remap]\n\nimporter="svg"\ntype="DPITexture"\n' > "$svg.import"
		echo "Marked $svg as scalable"
	fi
done
"$GODOT" --path . --headless --import
