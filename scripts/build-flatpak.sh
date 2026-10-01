#!/usr/bin/env bash
# Stage pinned build tools, then build against GNOME instead of host glibc.
# Invoke through mise: mise exec -- scripts/build-flatpak.sh <build-number>
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

build_number="${1:?usage: build-flatpak.sh <build-number>}"
[[ "$build_number" =~ ^[0-9]+$ ]] || exit 2
case "$(uname -m)" in
  x86_64) flatpak_arch=x86_64; asset_arch=x64 ;;
  aarch64) flatpak_arch=aarch64; asset_arch=arm64 ;;
  *) echo 'Unsupported Linux architecture' >&2; exit 2 ;;
esac

app_id=io.github.denysvitali.happy_flutter
manifest="packaging/flatpak/$app_id.yml"
stage=build/flatpak/source
test ! -e "$stage" || {
  echo "Remove $stage before staging another build" >&2
  exit 1
}
mkdir -p "$stage/toolchain"
# Only tracked sources enter the package. pubspec.lock is ignored by Git,
# but the host dependency resolution supplies the lock used by the SDK.
git archive HEAD | tar -x -C "$stage"
cp pubspec.lock "$stage/"
flutter_root="$(dirname "$(dirname "$(readlink -f "$(command -v flutter)")")")"
cp -a "$flutter_root" "$stage/toolchain/flutter"
cp "$(command -v mise)" "$stage/toolchain/mise"
touch "$stage/toolchain/mise.toml"
semver="$(awk '/^version:/ {print $2}' pubspec.yaml | cut -d+ -f1)"
printf '%s %s\n' "$semver" "$build_number" \
  > "$stage/packaging/flatpak/build-metadata"

flatpak-builder --user --force-clean --disable-rofiles-fuse \
  --install-deps-from=flathub --arch="$flatpak_arch" \
  --repo=build/flatpak/repo build/flatpak/app "$manifest"
flatpak build-bundle --arch="$flatpak_arch" \
  --runtime-repo=https://dl.flathub.org/repo/flathub.flatpakrepo \
  build/flatpak/repo "happy-flutter-linux-$asset_arch.flatpak" "$app_id"
