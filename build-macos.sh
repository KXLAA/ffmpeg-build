#!/usr/bin/env bash
# Builds for either Mac architecture on any Mac: clang cross-compiles with -target.
# Usage: PLATFORM=darwin-arm64 ./build-macos.sh

set -euo pipefail

cd "$(dirname "$0")"
BASE_DIR=$(pwd)
FFMPEG_EXECUTABLE=ffmpeg
source common.sh

case $PLATFORM in
    darwin-arm64)
        ARCH=arm64
        # LAME 3.100's config.sub predates Apple silicon: it knows aarch64, not arm64.
        LAME_HOST=aarch64-apple-darwin
        ;;
    darwin-x64)
        ARCH=x86_64
        LAME_HOST=x86_64-apple-darwin
        ;;
    *)
        fail "build-macos.sh doesn't build $PLATFORM"
        ;;
esac
# Cratebase's minimumSystemVersion.
TARGET=$ARCH-apple-macos13

build_lame --host=$LAME_HOST "CC=/usr/bin/clang -target $TARGET" "CFLAGS=-fPIC -target $TARGET"
# -dead_strip_dylibs: configure links CoreFoundation, CoreMedia and CoreVideo whenever it finds
# them, though nothing in this build uses them.
build_ffmpeg \
    --cc=/usr/bin/clang \
    --enable-cross-compile \
    --target-os=darwin \
    --arch=$ARCH \
    --extra-cflags="-target $TARGET" \
    --extra-ldflags="-target $TARGET -Wl,-dead_strip_dylibs" \
    --enable-runtime-cpudetect
