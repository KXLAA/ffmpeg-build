#!/usr/bin/env bash
# Builds a fully static binary against musl in Alpine, so it runs on any Linux of its architecture.
# Outside Alpine it runs itself in a container of the host's architecture (Docker).
# Usage: PLATFORM=linux-x64 ./build-linux.sh

set -euo pipefail

cd "$(dirname "$0")"

# alpine:3.22
ALPINE=alpine@sha256:5291449c3df73caf6ed85e649dec1b9e818b39a5d8c871e97afc13e9cd5e8fa8

if [ ! -e /etc/alpine-release ]; then
    exec docker run --rm -v "$PWD:/build" -w /build -e PLATFORM -e GITHUB_SHA "$ALPINE" \
        sh -c 'apk add --no-cache bash build-base curl nasm tar xz && ./build-linux.sh'
fi

BASE_DIR=$(pwd)
FFMPEG_EXECUTABLE=ffmpeg
source common.sh

case $PLATFORM in
    linux-x64) MACHINE=x86_64 ;;
    linux-arm64) MACHINE=aarch64 ;;
    *) fail "build-linux.sh doesn't build $PLATFORM" ;;
esac
if [ "$(uname -m)" != "$MACHINE" ]; then
    fail "$PLATFORM builds on an $MACHINE machine, not $(uname -m)"
fi

build_lame CFLAGS=-fPIC
build_ffmpeg --extra-ldflags=-static
