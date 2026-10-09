#!/usr/bin/env bash
# Exports the game for the web into build/web/ using the "Web" preset in export_presets.cfg.
# Needs Godot's export templates (Editor > Manage Export Templates > Download and Install).
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-/Applications/Godot-2.app/Contents/MacOS/Godot}"
mkdir -p build/web
"$GODOT" --path . --headless --export-release "Web" build/web/index.html
echo "Exported to build/web/. Run tools/serve_web.sh to play it on a phone."
