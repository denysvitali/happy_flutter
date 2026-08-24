#!/usr/bin/env bash
# Build the Rust hot-path core (rust/happy_core) for a target platform and
# drop the artifact where the Flutter build expects it.
#
#   scripts/build_rust.sh android   -> android/app/src/main/jniLibs/<abi>/
#   scripts/build_rust.sh linux     -> build/rust/linux/
#
# The app treats the native core as optional: NativeCore.ensureInitialized()
# degrades to the Dart path when the library is absent. So a failure here
# makes the app slower, never broken — which is why CI can run this without
# gating the build on it.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CRATE="$ROOT/rust/happy_core"
TARGET_PLATFORM="${1:-}"

if [[ -z "$TARGET_PLATFORM" ]]; then
  echo "usage: $0 <android|linux>" >&2
  exit 2
fi

command -v cargo >/dev/null 2>&1 || {
  echo "cargo not found on PATH; skipping native core build" >&2
  exit 0
}

case "$TARGET_PLATFORM" in
  android)
    : "${ANDROID_NDK_HOME:=${ANDROID_NDK_ROOT:-}}"
    if [[ -z "$ANDROID_NDK_HOME" || ! -d "$ANDROID_NDK_HOME" ]]; then
      echo "ANDROID_NDK_HOME is unset or missing; skipping native core" >&2
      exit 0
    fi

    # Only arm64 and x86_64 are built: armeabi-v7a is long tail on devices
    # that would not benefit, and every extra ABI is a full compile in CI.
    declare -A ABIS=(
      [aarch64-linux-android]=arm64-v8a
      [x86_64-linux-android]=x86_64
    )
    API_LEVEL="${ANDROID_API_LEVEL:-24}"
    TOOLCHAIN="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/bin"

    for TRIPLE in "${!ABIS[@]}"; do
      ABI="${ABIS[$TRIPLE]}"
      rustup target add "$TRIPLE" >/dev/null 2>&1 || true

      # Cargo needs an explicit linker per Android triple; the NDK ships one
      # clang wrapper per (triple, API level).
      LINKER_VAR="CARGO_TARGET_$(echo "$TRIPLE" | tr '[:lower:]-' '[:upper:]_')_LINKER"
      export "$LINKER_VAR=$TOOLCHAIN/${TRIPLE/aarch64/aarch64}${API_LEVEL}-clang"

      echo "==> building happy_core for $TRIPLE ($ABI)"
      (cd "$CRATE" && cargo build --release --target "$TRIPLE")

      DEST="$ROOT/android/app/src/main/jniLibs/$ABI"
      mkdir -p "$DEST"
      cp "$CRATE/target/$TRIPLE/release/libhappy_core.so" "$DEST/"
      echo "==> installed $DEST/libhappy_core.so"
    done
    ;;

  linux)
    echo "==> building happy_core for the host"
    (cd "$CRATE" && cargo build --release)
    DEST="$ROOT/build/rust/linux"
    mkdir -p "$DEST"
    cp "$CRATE/target/release/libhappy_core.so" "$DEST/"
    echo "==> installed $DEST/libhappy_core.so"
    ;;

  *)
    echo "unknown platform: $TARGET_PLATFORM (expected android or linux)" >&2
    exit 2
    ;;
esac
