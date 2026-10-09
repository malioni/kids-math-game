#!/usr/bin/env bash
# Serves build/web/ to phones and tablets.
#
#   tools/serve_web.sh            plain http on the local Wi-Fi (works for desktop browsers on
#                                 this Mac via localhost, but iPhones refuse to run Godot over http)
#   tools/serve_web.sh --tunnel   also opens a temporary https address through a Cloudflare quick
#                                 tunnel, which iPhones accept; needs: brew install cloudflared
#
# Ctrl+C stops everything.
set -euo pipefail
cd "$(dirname "$0")/../build/web"
PORT=8000
TUNNEL=0
# ${1+"$@"} instead of "$@": bash 3.2 (macOS) treats an empty "$@" as unbound under set -u.
for arg in ${1+"$@"}; do
	case "$arg" in
		--tunnel) TUNNEL=1 ;;
		*) PORT="$arg" ;;
	esac
done

if [ "$TUNNEL" -eq 0 ]; then
	IP="$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || true)"
	echo "Open:  http://${IP:-YOUR-MAC-IP}:${PORT}   (iPhone Safari needs --tunnel instead)"
	exec python3 -m http.server "$PORT" --bind 0.0.0.0
fi

if ! command -v cloudflared >/dev/null 2>&1; then
	echo "cloudflared is not installed. Install it with:  brew install cloudflared"
	exit 1
fi

python3 -m http.server "$PORT" --bind 127.0.0.1 >/dev/null 2>&1 &
SERVER_PID=$!
trap 'kill "$SERVER_PID" 2>/dev/null || true' EXIT
echo "Starting tunnel. Open the https://....trycloudflare.com address it prints on your iPhone."
cloudflared tunnel --no-autoupdate --url "http://127.0.0.1:${PORT}"
