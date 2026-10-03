#!/usr/bin/env bash
# Cross-builds for Windows on Linux with mingw-w64 (Ubuntu: apt-get install mingw-w64 nasm).
# Windows on Arm runs it under x64 emulation.
# Usage: PLATFORM=win32-x64 ./build-windows.sh

set -euo pipefail

cd "$(dirname "$0")"
BASE_DIR=$(pwd)
FFMPEG_EXECUTABLE=ffmpeg.exe
source common.sh

case $PLATFORM in
    win32-x64) ARCH=x86_64 ;;
    *) fail "build-windows.sh doesn't build $PLATFORM" ;;
esac

build_lame --host=$ARCH-w64-mingw32
build_ffmpeg \
    --target-os=mingw32 \
    --arch=$ARCH \
    --cross-prefix=$ARCH-w64-mingw32- \
    --extra-cflags='-static -static-libgcc' \
    --extra-ldflags='-static -static-libgcc'
