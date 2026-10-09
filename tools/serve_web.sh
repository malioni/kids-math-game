#!/usr/bin/env bash
# Serves build/web/ to phones and tablets on the same Wi-Fi network.
# Usage: tools/serve_web.sh [port]   (default 8000; Ctrl+C to stop)
set -euo pipefail
cd "$(dirname "$0")/../build/web"
PORT="${1:-8000}"
IP="$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || true)"
echo "On your iPhone (same Wi-Fi), open:  http://${IP:-<this-Mac's-IP>}:${PORT}"
echo "If macOS asks whether python3 may accept incoming connections, choose Allow."
python3 -m http.server "$PORT" --bind 0.0.0.0
