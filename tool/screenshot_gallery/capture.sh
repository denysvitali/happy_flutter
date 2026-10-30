#!/usr/bin/env bash
# Build the screenshot gallery for web, serve it, and capture scenes.
#
#   tool/screenshot_gallery/capture.sh <out-dir> [--skip-build] \
#       [--scenes a,b] [--themes dark,light] [--desktop a,b|none]
#
# Env: GALLERY_BUILD_DIR (default /home/workspace/ux-research/2026-10-29/rig-build)
#      GALLERY_PORT      (default: first free port from 8765)
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/../.." && pwd)"
out="${1:?usage: capture.sh <out-dir> [--skip-build] [capture.mjs args...]}"
shift
skip_build=0
passthrough=()
for a in "$@"; do
  if [[ "$a" == "--skip-build" ]]; then skip_build=1; else passthrough+=("$a"); fi
done

build_dir="${GALLERY_BUILD_DIR:-/home/workspace/ux-research/2026-10-29/rig-build}"

if [[ $skip_build -eq 0 ]]; then
  echo "==> building gallery into $build_dir"
  start=$(date +%s)
  (cd "$repo" && flock /tmp/happy-flutter-build.lock mise exec -- flutter build web \
    -t tool/screenshot_gallery/main.dart -o "$build_dir" \
    --no-web-resources-cdn --no-wasm-dry-run)
  echo "==> build took $(( $(date +%s) - start ))s"
fi
[[ -f "$build_dir/index.html" ]] || { echo "no build at $build_dir" >&2; exit 2; }

port="${GALLERY_PORT:-}"
if [[ -z "$port" ]]; then
  port=$(python3 -c 'import socket
for p in range(8765, 8865):
    s = socket.socket()
    try:
        s.bind(("127.0.0.1", p)); print(p); break
    except OSError: pass
    finally: s.close()')
fi

python3 -m http.server "$port" --bind 127.0.0.1 --directory "$build_dir" \
  >/tmp/gallery-http-$port.log 2>&1 &
server=$!
trap 'kill $server 2>/dev/null || true' EXIT
for _ in $(seq 1 50); do
  curl -fs "http://127.0.0.1:$port/index.html" >/dev/null && break
  sleep 0.1
done

export LD_LIBRARY_PATH=/home/workspace/.cache/hive-chromelibs/root/usr/lib/x86_64-linux-gnu${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}
export NODE_PATH="${NODE_PATH:-/home/workspace/ui-audits/happy-2026-10-02/node_modules}"
status=0
start=$(date +%s)
node "$here/capture.mjs" --url "http://127.0.0.1:$port" \
  --out "$out" "${passthrough[@]}" || status=$?
echo "==> capture took $(( $(date +%s) - start ))s"
exit $status
