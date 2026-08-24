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

    if [[ ! -d "$TOOLCHAIN" ]]; then
      echo "NDK toolchain not at $TOOLCHAIN; skipping native core" >&2
      exit 0
    fi

    for TRIPLE in "${!ABIS[@]}"; do
      ABI="${ABIS[$TRIPLE]}"

      # The NDK ships one clang wrapper per (triple, API level). If the exact
      # wrapper is missing, skip this ABI rather than failing the build — the
      # app runs fine without the library.
      LINKER="$TOOLCHAIN/${TRIPLE}${API_LEVEL}-clang"
      if [[ ! -x "$LINKER" ]]; then
        echo "no linker at $LINKER; skipping $ABI" >&2
        continue
      fi

      if ! rustup target add "$TRIPLE" >/dev/null 2>&1; then
        echo "cannot add rust target $TRIPLE; skipping $ABI" >&2
        continue
      fi

      # cargo reads CARGO_TARGET_<TRIPLE>_LINKER with the triple uppercased
      # and dashes turned into underscores.
      LINKER_VAR="CARGO_TARGET_$(printf '%s' "$TRIPLE" | tr 'a-z-' 'A-Z_')_LINKER"
      export "${LINKER_VAR}=${LINKER}"
      # cc-rs (pulled in by some transitive deps) keys off these instead.
      export "CC_${TRIPLE//-/_}=${LINKER}"
      export "AR_${TRIPLE//-/_}=$TOOLCHAIN/llvm-ar"

      echo "==> building happy_core for $TRIPLE ($ABI) via $(basename "$LINKER")"
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
