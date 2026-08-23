#!/usr/bin/env bash
#
# Installer for the Happy Flutter Linux x64 release bundle.
#
#   ./install-linux.sh                 install/upgrade into ~/.local/share
#   ./install-linux.sh --no-autoupdate install without the background timer
#   ./install-linux.sh --uninstall     remove app, units and desktop entry
#
# Installs to $XDG_DATA_HOME/happy_flutter, exposes ~/.local/bin/happy_flutter,
# registers a desktop entry, and (by default) arms a systemd user timer that
# runs update-linux.sh daily so the app stays current even when it is not
# running. The app itself also self-updates at runtime.

set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
bundle_dir="${XDG_DATA_HOME:-$HOME/.local/share}/happy_flutter"
applications_dir="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
bin_dir="$HOME/.local/bin"
config_dir="${XDG_CONFIG_HOME:-$HOME/.config}"
systemd_dir="$config_dir/systemd/user"
service_name="happy-flutter-updater.service"
timer_name="happy-flutter-updater.timer"
desktop_file="$applications_dir/com.example.happy_flutter.desktop"

UNINSTALL=0
ENABLE_AUTOUPDATE=1

for arg in "$@"; do
  case "$arg" in
    --no-autoupdate) ENABLE_AUTOUPDATE=0 ;;
    --uninstall) UNINSTALL=1 ;;
    *) echo "usage: $0 [--no-autoupdate] [--uninstall]" >&2; exit 1 ;;
  esac
done

if [[ "$UNINSTALL" -eq 1 ]]; then
  # Stop the background updater before touching the bundle.
  if command -v systemctl >/dev/null 2>&1; then
    systemctl --user disable --now "$timer_name" >/dev/null 2>&1 || true
  fi
  rm -f "$systemd_dir/$timer_name" "$systemd_dir/$service_name"
  rm -f "$bin_dir/happy_flutter" "$desktop_file"
  rm -rf -- "$bundle_dir"
  # Leftovers from interrupted updates (staging/backup/lock).
  rm -f -- "$(dirname "$bundle_dir")"/.happy_flutter.update.lock
  rm -rf -- "$(dirname "$bundle_dir")"/.happy_flutter.update.* \
           "$(dirname "$bundle_dir")"/.happy_flutter.backup.* 2>/dev/null || true
  if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$applications_dir" >/dev/null 2>&1 || true
  fi
  systemctl --user daemon-reload >/dev/null 2>&1 || true
  echo "Happy Flutter uninstalled."
  exit 0
fi

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

# Stamp/refresh the update manifest so both the in-app updater and
# update-linux.sh can compare installed vs latest builds.
# Precedence: CI-stamped manifest from the archive > explicit env override >
# previously recorded version > unknown (0.0.0+0, so the next updater pass
# pulls the user to the newest official build).
manifest_tmp="$temporary_dir/manifest.json"
previous_manifest="$bundle_dir/manifest.json"
installed_at_ms=$(( $(date +%s) * 1000 ))
if [[ ! -s "$manifest_tmp" && -s "$previous_manifest" && -z "${HAPPY_VERSION:-}" ]]; then
  cp "$previous_manifest" "$manifest_tmp"
fi
if [[ ! -s "$manifest_tmp" ]]; then
  cat > "$manifest_tmp" <<EOF
{
  "name": "happy_flutter",
  "version": "${HAPPY_VERSION:-0.0.0}",
  "buildNumber": ${HAPPY_BUILD_NUMBER:-0},
  "channel": "stable",
  "installPath": "$bundle_dir",
  "installedAtMs": $installed_at_ms
}
EOF
fi

chmod +x "$temporary_dir/happy_flutter" "$temporary_dir/install-linux.sh"
chmod +x "$temporary_dir/update-linux.sh" 2>/dev/null || true

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

# ── Background auto-update timer ──────────────────────────────────────────────
# Keeps the bundle current even while the app is not running. The updater is
# safe to run concurrently with a live app (atomic dir swap); the in-app
# updater takes its own lock via flock.
autoupdate_note="Background auto-update not armed; the app still self-updates while running."
if [[ "$ENABLE_AUTOUPDATE" -eq 1 ]] && command -v systemctl >/dev/null 2>&1; then
  mkdir -p "$systemd_dir"
  cat > "$systemd_dir/$service_name" <<EOF
[Unit]
Description=Happy Flutter background self-update
Documentation=https://github.com/denysvitali/happy_flutter

[Service]
Type=oneshot
ExecStart=$bundle_dir/update-linux.sh --quiet
NoNewPrivileges=true
PrivateTmp=true
EOF

  cat > "$systemd_dir/$timer_name" <<EOF
[Unit]
Description=Run Happy Flutter self-update periodically

[Timer]
OnBootSec=15min
OnUnitActiveSec=12h
RandomizedDelaySec=10min
Persistent=true

[Install]
WantedBy=timers.target
EOF

  systemctl --user daemon-reload >/dev/null 2>&1 || true
  if systemctl --user enable --now "$timer_name" >/dev/null 2>&1; then
    autoupdate_note="Background auto-update enabled (systemd user timer, every 12h)."
  else
    autoupdate_note="Auto-update timer could not be enabled; run $bundle_dir/update-linux.sh manually or re-run this installer inside a systemd user session."
  fi
fi

echo "Happy Flutter installed to $bundle_dir"
echo "Open it from your launcher or run $bin_dir/happy_flutter"
echo "$autoupdate_note"
