#!/usr/bin/env bash

set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
bundle_dir="${XDG_DATA_HOME:-$HOME/.local/share}/happy_flutter"
applications_dir="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
bin_dir="$HOME/.local/bin"
desktop_file="$applications_dir/com.example.happy_flutter.desktop"

if [[ ! -x "$script_dir/happy_flutter" ]]; then
  echo "error: install-linux.sh must be run from the extracted release archive" >&2
  exit 1
fi

if [[ -L "$bundle_dir" || ( -e "$bundle_dir" && ! -d "$bundle_dir" ) ]]; then
  echo "error: refusing to replace non-directory install path: $bundle_dir" >&2
  exit 1
fi

mkdir -p "$applications_dir" "$bin_dir"
temporary_dir=$(mktemp -d "${bundle_dir%/*}/.happy_flutter.XXXXXX")
cleanup() {
  rm -rf -- "$temporary_dir"
}
trap cleanup EXIT

cp -a "$script_dir/." "$temporary_dir"
rm -rf -- "$bundle_dir"
mv "$temporary_dir" "$bundle_dir"
trap - EXIT

ln -sfn "$bundle_dir/happy_flutter" "$bin_dir/happy_flutter"

desktop_escape() {
  sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'
}

escaped_binary=$(printf '%s' "$bundle_dir/happy_flutter" | desktop_escape)
escaped_icon=$(printf '%s' "$bundle_dir/happy_flutter.png" | desktop_escape)
cat > "$desktop_file" <<EOF
[Desktop Entry]
Type=Application
Name=Happy Flutter
Comment=Mobile client for Claude Code sessions
Exec="$escaped_binary"
TryExec="$escaped_binary"
Icon=$escaped_icon
Terminal=false
Categories=Development;Utility;
StartupWMClass=com.example.happy_flutter
EOF

if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database "$applications_dir" >/dev/null 2>&1 || true
fi

echo "Happy Flutter installed to $bundle_dir"
echo "Open it from your launcher or run $bin_dir/happy_flutter"
