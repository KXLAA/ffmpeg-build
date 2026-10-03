#!/usr/bin/env bash
# Sourced by the build scripts after they set BASE_DIR, PLATFORM and FFMPEG_EXECUTABLE.

FFMPEG_VERSION=8.1.2
FFMPEG_TARBALL=ffmpeg-$FFMPEG_VERSION.tar.xz
FFMPEG_TARBALL_URL=https://ffmpeg.org/releases/$FFMPEG_TARBALL
# Checked against the release's signature by FFmpeg's release key (FCF986EA15E6E293A5644F10B4322F04D67658D8).
FFMPEG_SHA256=464beb5e7bf0c311e68b45ae2f04e9cc2af88851abb4082231742a74d97b524c

# The MP3 encoder: ffmpeg has no native one. LGPL, like these builds.
LAME_VERSION=3.100
LAME_TARBALL=lame-$LAME_VERSION.tar.gz
LAME_TARBALL_URL=https://downloads.sourceforge.net/project/lame/lame/$LAME_VERSION/$LAME_TARBALL
LAME_SHA256=ddfe36cab873794038ae2c1210557ad34857a4b6bdc515785d1da9e175b1da1e

# shellcheck disable=SC2054 # ffmpeg takes comma-separated lists of components
FFMPEG_CONFIGURE_FLAGS=(
    --disable-shared
    --enable-static
    --enable-pic
    # Only what's listed below: no library from the build machine links in by being installed
    # there (acoustid/ffmpeg-build's arm64 macOS binary picked up Homebrew's libX11 that way).
    --disable-autodetect
    --disable-everything
    --disable-doc
    --disable-debug
    --disable-network
    --disable-programs
    --enable-ffmpeg
    --disable-avdevice
    --disable-swscale

    --enable-protocol=file,pipe

    # Read: every audio file extension Cratebase imports.
    --enable-demuxer=aac,aiff,asf,flac,matroska,mov,mp3,ogg,wav
    --enable-decoder=aac,alac,flac,mp3,mp3float,opus,vorbis,wmav1,wmav2,wmapro,wmalossless
    --enable-decoder=pcm_s16le,pcm_s16be,pcm_s24le,pcm_s24be,pcm_s32le,pcm_s32be
    --enable-decoder=pcm_f32le,pcm_f32be,pcm_f64le,pcm_u8,pcm_alaw,pcm_mulaw
    --enable-parser=aac,flac,mpegaudio,opus,vorbis

    # Write: float PCM to a pipe for decoding, and the formats Cratebase transcodes to.
    --enable-libmp3lame
    --enable-encoder=pcm_f32le,pcm_s16le,pcm_s24le,pcm_s16be,pcm_s24be,flac,alac,aac,libmp3lame
    --enable-muxer=wav,aiff,flac,mp3,ipod,mp4,adts
    --enable-bsf=aac_adtstoasc
    --enable-filter=aformat,anull,aresample,atrim,format,null
)

: "${PLATFORM:?set PLATFORM to darwin-arm64, darwin-x64, linux-arm64, linux-x64 or win32-x64}"

JOBS=$(getconf _NPROCESSORS_ONLN)
WORK_DIR=$(mktemp -d)
trap 'rm -rf "$WORK_DIR"' EXIT
DEPS_DIR=$WORK_DIR/deps

fail() {
    echo "$*" >&2
    exit 1
}

sha256() {
    if command -v sha256sum >/dev/null; then sha256sum "$1"; else shasum -a 256 "$1"; fi | cut -d ' ' -f 1
}

# Downloads a source tarball into BASE_DIR, once, and checks it against its pin.
fetch() {
    local url=$1 file=$2 pinned=$3
    [ -e "$BASE_DIR/$file" ] || curl -sfL -o "$BASE_DIR/$file" "$url"
    local actual
    actual=$(sha256 "$BASE_DIR/$file")
    if [ "$actual" != "$pinned" ]; then
        rm -f "$BASE_DIR/$file"
        fail "$file has sha256 $actual, not the pinned $pinned"
    fi
}

# A static libmp3lame in DEPS_DIR. The arguments go to LAME's configure: the target's toolchain.
build_lame() {
    fetch "$LAME_TARBALL_URL" "$LAME_TARBALL" "$LAME_SHA256"
    mkdir "$WORK_DIR/lame"
    tar -xzf "$BASE_DIR/$LAME_TARBALL" --strip-components=1 -C "$WORK_DIR/lame"
    (
        cd "$WORK_DIR/lame" || exit
        ./configure --prefix="$DEPS_DIR" --enable-static --disable-shared \
            --disable-frontend --disable-decoder --disable-gtktest "$@"
        make -j"$JOBS"
        make install
    )
}

# ffmpeg against that LAME, packaged as dist/ffmpeg-<version>-<platform>.tar.gz. The arguments
# are the target's extra configure flags.
build_ffmpeg() {
    fetch "$FFMPEG_TARBALL_URL" "$FFMPEG_TARBALL" "$FFMPEG_SHA256"
    mkdir "$WORK_DIR/ffmpeg"
    tar -xJf "$BASE_DIR/$FFMPEG_TARBALL" --strip-components=1 -C "$WORK_DIR/ffmpeg"
    local flags=(
        "${FFMPEG_CONFIGURE_FLAGS[@]}"
        --extra-cflags="-I$DEPS_DIR/include"
        --extra-ldflags="-L$DEPS_DIR/lib"
        "$@"
    )
    (
        cd "$WORK_DIR/ffmpeg" || exit
        ./configure "${flags[@]}" || { tail -n 50 ffbuild/config.log; exit 1; }
        make -j"$JOBS"
    )

    local stage=$WORK_DIR/package
    mkdir "$stage"
    cp "$WORK_DIR/ffmpeg/$FFMPEG_EXECUTABLE" "$stage/"
    chmod 755 "$stage/$FFMPEG_EXECUTABLE"
    cp "$WORK_DIR/ffmpeg/COPYING.LGPLv2.1" "$stage/LICENSE.LGPL"
    {
        echo "FFmpeg $FFMPEG_VERSION for $PLATFORM, built by https://github.com/KXLAA/ffmpeg-build"
        echo "at commit ${GITHUB_SHA:-(a local build)}."
        echo
        echo "LGPL-2.1-or-later: configured without --enable-gpl or --enable-nonfree. LAME $LAME_VERSION"
        echo "(LGPL) is linked statically."
        echo
        echo "Sources:"
        echo "  $FFMPEG_TARBALL_URL"
        echo "    sha256 $FFMPEG_SHA256"
        echo "  $LAME_TARBALL_URL"
        echo "    sha256 $LAME_SHA256"
        echo
        echo "Configure flags:"
        printf '  %s\n' "${flags[@]//$DEPS_DIR/<lame>}"
    } >"$stage/BUILD.txt"

    mkdir -p "$BASE_DIR/dist"
    local tarball=$BASE_DIR/dist/ffmpeg-$FFMPEG_VERSION-$PLATFORM.tar.gz
    tar -czf "$tarball" -C "$stage" "$FFMPEG_EXECUTABLE" LICENSE.LGPL BUILD.txt
    echo "Built $tarball"
}
