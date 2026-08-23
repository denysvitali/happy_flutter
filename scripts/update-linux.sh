#!/usr/bin/env bash
#
# Self-updater for locally-installed Happy Flutter Linux bundles.
#
# Mirrors lib/core/services/desktop_updater_service.dart: fetches the newest
# GitHub release, compares it against the installed manifest.json, then swaps
# a freshly extracted staging dir into place atomically. Safe to run while the
# app is open — running processes keep their open files; the new version is
# picked up on next launch.
#
# Usage:
#   update-linux.sh [--check] [--force] [--quiet]
#
# Exit codes:
#   0   up-to-date or update applied successfully
#   10  (--check only) an update is available
#   1   usage/environment error
#   2   network failure
#   3   download/verification failure
#   4   swap failure (previous install restored)

set -euo pipefail

ASSET_NAME="happy-flutter-linux-x64.tar.gz"
MANIFEST_NAME="manifest.json"
REPO="${HAPPY_UPDATE_REPO:-denysvitali/happy_flutter}"

MODE_CHECK=0
FORCE=0
QUIET=0

for arg in "$@"; do
  case "$arg" in
    --check) MODE_CHECK=1 ;;
    --force) FORCE=1 ;;
    --quiet) QUIET=1 ;;
    *) echo "usage: $0 [--check] [--force] [--quiet]" >&2; exit 1 ;;
  esac
done

log() {
  [ "$QUIET" -eq 1 ] && return 0
  printf '%s\n' "$*"
}

warn() {
  printf 'warning: %s\n' "$*" >&2
}

# ── Locate the managed install dir ────────────────────────────────────────────
INSTALL_DIR="${HAPPY_INSTALL_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/happy_flutter}"
if [[ ! -x "$INSTALL_DIR/happy_flutter" ]]; then
  log "No managed install found at $INSTALL_DIR"
  exit 1
fi
PARENT_DIR=$(dirname "$INSTALL_DIR")

# ── Single-instance lock (app updater and timer must not race) ───────────────
LOCK_FILE="$PARENT_DIR/.happy_flutter.update.lock"
if command -v flock >/dev/null 2>&1; then
  exec 9>"$LOCK_FILE"
  if ! flock -n 9; then
    log "Another update is already in progress"
    exit 0
  fi
fi

# ── Manifest helpers (flat JSON, no jq dependency) ───────────────────────────
manifest_value() {
  local key=$1 file="$INSTALL_DIR/$MANIFEST_NAME" value=""
  if [[ -f "$file" ]]; then
    # Capture stops at quotes/commas so quoted strings AND bare numbers
    # with trailing JSON commas both come through clean.
    value=$(sed -n "s/.*\"$key\"[[:space:]]*:[[:space:]]*\"\{0,1\}\([^\"]*\)\"\{0,1\}.*/\1/p" "$file" | head -n1 | tr -d ',')
  fi
  printf '%s' "$value"
}

semver_of_tag() {
  local tag=$1
  tag=${tag#v}
  tag=${tag#V}
  printf '%s' "${tag%%-*}"
}

build_of_tag() {
  local tag=$1 suffix
  tag=${tag#v}
  tag=${tag#V}
  suffix=${tag#*-}
  # No dash (or non-numeric suffix): semver-only tag, build defaults to 0.
  if [[ "$suffix" == "$tag" || ! "$suffix" =~ ^[0-9]+$ ]]; then
    printf '0'
  else
    printf '%s' "$suffix"
  fi
}

# Returns 0 when the candidate release is strictly newer than current.
# Semver compares first (sort -V); the numeric build suffix breaks ties.
is_newer() {
  local cur_sem=$1 cur_build=$2 cand_sem=$3 cand_build=$4 lowest
  lowest=$(printf '%s\n%s\n' "$cur_sem" "$cand_sem" | sort -V | head -n1)
  if [[ "$lowest" != "$cand_sem" ]]; then
    return 0   # current sorts below candidate -> candidate newer
  fi
  if [[ "$lowest" != "$cur_sem" ]]; then
    return 1   # candidate sorts below current -> older
  fi
  (( cand_build > cur_build ))
}

CURRENT_SEMVER=$(manifest_value version)
case "$CURRENT_SEMVER" in
  '' ) CURRENT_SEMVER="0.0.0" ;;
  *-*) CURRENT_SEMVER="${CURRENT_SEMVER%%-*}" ;;
esac
CURRENT_BUILD=$(manifest_value buildNumber)
[[ "$CURRENT_BUILD" =~ ^[0-9]+$ ]] || CURRENT_BUILD=0

# ── Query the latest release ─────────────────────────────────────────────────
API_URL="https://api.github.com/repos/$REPO/releases/latest"
RELEASE_JSON=""
if ! RELEASE_JSON=$(curl -fsSL --max-time 20 \
    -H 'Accept: application/vnd.github+json' \
    -H 'User-Agent: happy-flutter-updater' \
    "$API_URL"); then
  warn "Failed to query $API_URL"
  exit 2
fi

TAG=$(sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' <<<"$RELEASE_JSON" | head -n1)
if [[ -z "$TAG" ]]; then
  warn "Release feed returned no tag_name"
  exit 2
fi

LATEST_SEMVER=$(semver_of_tag "$TAG")
LATEST_BUILD=$(build_of_tag "$TAG")

if [[ "$FORCE" -ne 1 ]] && ! is_newer "$CURRENT_SEMVER" "$CURRENT_BUILD" \
    "$LATEST_SEMVER" "$LATEST_BUILD"; then
  log "Up to date (installed $CURRENT_SEMVER+$CURRENT_BUILD, latest $TAG)"
  exit 0
fi

if [[ "$MODE_CHECK" -eq 1 ]]; then
  log "Update available: $TAG (installed $CURRENT_SEMVER+$CURRENT_BUILD)"
  exit 10
fi

ASSET_URL=$( { grep -o "\"browser_download_url\"[[:space:]]*:[[:space:]]*\"[^\"]*$ASSET_NAME\"" <<<"$RELEASE_JSON" || true; } \
  | head -n1 | sed 's/.*"\(.*\)"/\1/')
if [[ -z "$ASSET_URL" ]]; then
  warn "Release $TAG does not carry $ASSET_NAME"
  exit 3
fi

log "Downloading $TAG ..."
STAMP=$(date +%s)
STAGING="$PARENT_DIR/.happy_flutter.update.$STAMP"
BACKUP="$PARENT_DIR/.happy_flutter.backup.$STAMP"
ARCHIVE="$STAGING.tar.gz"

cleanup_staging() {
  rm -rf -- "$STAGING" "$ARCHIVE"
}

rollback() {
  rm -rf -- "$STAGING" "$ARCHIVE" "$BACKUP"
  warn "Update aborted; previous installation left intact"
  exit 3
}

mkdir -p "$STAGING"
trap cleanup_staging EXIT

if ! curl -fSL --max-time 300 --retry 2 -o "$ARCHIVE" "$ASSET_URL"; then
  rollback
fi

if ! tar -xzf "$ARCHIVE" -C "$STAGING"; then
  warn "Downloaded bundle failed to extract"
  rollback
fi
rm -f "$ARCHIVE"

if [[ ! -e "$STAGING/happy_flutter" ]]; then
  warn "Downloaded bundle is missing its executable"
  rollback
fi
chmod +x "$STAGING/happy_flutter"
chmod +x "$STAGING/install-linux.sh" "$STAGING/update-linux.sh" 2>/dev/null || true

NEW_VERSION="${TAG#[vV]}"
NEW_VERSION="${NEW_VERSION%%-*}"

cat > "$STAGING/$MANIFEST_NAME" <<EOF
{
  "name": "happy_flutter",
  "version": "$NEW_VERSION",
  "buildNumber": $LATEST_BUILD,
  "channel": "stable",
  "installedAtMs": $(( STAMP * 1000 ))
}
EOF

# Atomic-ish swap: old aside, staging in, backup dropped. The path never
# changes, so launchers and ~/.local/bin symlinks stay valid.
if ! mv "$INSTALL_DIR" "$BACKUP"; then
  warn "Could not move the current installation aside"
  rollback
fi
if ! mv "$STAGING" "$INSTALL_DIR"; then
  if [[ -d "$BACKUP" && ! -d "$INSTALL_DIR" ]]; then
    mv "$BACKUP" "$INSTALL_DIR"
  fi
  warn "Failed to move new bundle into place; previous installation restored"
  exit 4
fi
rm -rf -- "$BACKUP"
trap - EXIT

log "Updated to $TAG at $INSTALL_DIR"
log "Restart Happy Flutter to run the new version."
