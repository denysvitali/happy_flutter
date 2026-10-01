#!/usr/bin/env bash
set -euo pipefail

case "$FLATPAK_ARCH" in
  x86_64) flutter_arch=x64 ;;
  aarch64) flutter_arch=arm64 ;;
  *) echo "Unsupported Flatpak architecture: $FLATPAK_ARCH" >&2; exit 2 ;;
esac

# An empty mise config avoids installing host Java/Make in the SDK.
# The staged Flutter SDK is the version pinned by the repository.
export PATH="$PWD/toolchain/flutter/bin:$PATH"
export JAVA_HOME=/usr/lib/sdk/openjdk21/jvm/openjdk-21
# JNI is a transitive plugin dependency even on Linux. Keep its JVM
# independent of any host Java installation and omit unused Java modules.
"$JAVA_HOME/bin/jlink" --add-modules java.base --output /app/jre \
  --strip-debug --no-man-pages --no-header-files
toolchain/mise exec -- flutter config --no-analytics
toolchain/mise exec -- flutter pub get --enforce-lockfile
read -r semver build_number < packaging/flatpak/build-metadata
toolchain/mise exec -- flutter build linux --release --no-pub \
  --build-name="$semver" --build-number="$build_number" \
  --dart-define="SENTRY_RELEASE=happy_flutter@$semver+$build_number" \
  --dart-define="SENTRY_DIST=$build_number"

bundle="build/linux/$flutter_arch/release/bundle"
test -s "$bundle/lib/libhappy_core.so"
# Check every bundled ELF against the SDK, rather than the Ubuntu host.
while IFS= read -r -d '' elf; do
  LD_LIBRARY_PATH="$PWD/$bundle/lib:/app/jre/lib/server" \
    ldd "$elf" | tee /tmp/happy-flatpak-ldd
  awk '/not found/ { missing = 1 } END { exit missing }' \
    /tmp/happy-flatpak-ldd
done < <(find "$bundle" -type f \( -name '*.so*' -o -name happy_flutter \) -print0)

install -d /app/lib/happy_flutter /app/bin
cp -a "$bundle/." /app/lib/happy_flutter/
ln -s /app/lib/happy_flutter/happy_flutter /app/bin/happy_flutter
install -Dm644 "packaging/flatpak/$FLATPAK_ID.desktop" \
  "/app/share/applications/$FLATPAK_ID.desktop"
install -Dm644 "packaging/flatpak/$FLATPAK_ID.metainfo.xml" \
  "/app/share/metainfo/$FLATPAK_ID.metainfo.xml"
install -Dm644 assets/icon/app_icon.png \
  "/app/share/icons/hicolor/1024x1024/apps/$FLATPAK_ID.png"
