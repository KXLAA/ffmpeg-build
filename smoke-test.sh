#!/usr/bin/env bash
# Checks a release tarball on the platform it was built for: it holds a runnable ffmpeg of the
# pinned version that links nothing outside the OS, decodes every fixture the way Cratebase does,
# and encodes to each format Cratebase transcodes to.
# Usage: ./smoke-test.sh dist/ffmpeg-8.1.2-darwin-arm64.tar.gz

set -euo pipefail

tarball=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
cd "$(dirname "$0")"

fail() {
    echo "$*" >&2
    exit 1
}

version=$(sed -n 's/^FFMPEG_VERSION=//p' common.sh)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
tar -xzf "$tarball" -C "$work"

case $(uname -s) in
    MINGW* | MSYS*) ffmpeg=$work/ffmpeg.exe ;;
    *) ffmpeg=$work/ffmpeg ;;
esac
[ -x "$ffmpeg" ] || fail "$tarball has no executable $(basename "$ffmpeg") at its root"
for file in LICENSE.LGPL BUILD.txt; do
    [ -s "$work/$file" ] || fail "$tarball has no $file"
done

reported=$("$ffmpeg" -hide_banner -version)
reported=${reported%%$'\n'*}
[[ $reported == "ffmpeg version $version "* ]] || fail "The binary reports \"$reported\", not $version"

# Each tool runs on its own, so a missing or failing one fails the test instead of finding nothing.
case $(uname -s) in
    Darwin)
        linked=$(otool -L "$ffmpeg") || fail "otool can't read the binary"
        linked=$(tail -n +2 <<<"$linked" | awk '{ print $1 }')
        foreign=$(grep -v -E '^/(usr/lib|System)/' <<<"$linked" || true)
        ;;
    Linux)
        headers=$(readelf -l "$ffmpeg") || fail "readelf can't read the binary"
        foreign=$(grep 'program interpreter' <<<"$headers" || true)
        linked=${foreign:-nothing (static)}
        ;;
    MINGW* | MSYS*)
        linked=$(ldd "$ffmpeg") || fail "ldd can't read the binary"
        linked=$(awk '{ print $3 }' <<<"$linked")
        foreign=$(grep -v -i '^/c/windows/' <<<"$linked" || true)
        ;;
    *) fail "No linkage check for $(uname -s)" ;;
esac
[ -n "$linked" ] || fail "Found no libraries at all, so the check can't be trusted"
echo "links: $(tr '\n' ' ' <<<"$linked")"
[ -z "$foreign" ] || fail "The binary links libraries outside the OS: $foreign"

# Cratebase's decode (apps/server/src/audio/AudioDecoder.ts): the first audio stream as float WAV.
decode() {
    "$ffmpeg" -hide_banner -nostdin -nostats -loglevel error -i "$1" -map 0:a:0 -map_metadata -1 \
        -fflags +bitexact -codec:a pcm_f32le -f wav pipe:1 | wc -c | tr -d ' '
}

# A second of stereo float samples at 44.1 kHz is 352,800 bytes, less what encoders trim.
MIN_BYTES=340000

for fixture in fixtures/*; do
    bytes=$(decode "$fixture") || fail "$fixture didn't decode"
    [ "$bytes" -ge $MIN_BYTES ] || fail "$fixture decoded to only $bytes bytes"
    echo "decoded $fixture"
done

for target in mp3:libmp3lame m4a:aac alac.m4a:alac flac:flac wav:pcm_s24le aiff:pcm_s16be; do
    extension=${target%%:*}
    codec=${target#*:}
    output=$work/encoded.$extension
    "$ffmpeg" -hide_banner -nostdin -loglevel error -i fixtures/tone.flac -codec:a "$codec" "$output" ||
        fail "Couldn't encode $codec to .$extension"
    bytes=$(decode "$output") || fail ".$extension from $codec didn't decode"
    [ "$bytes" -ge $MIN_BYTES ] || fail ".$extension from $codec decoded to only $bytes bytes"
    echo "encoded $codec to .$extension"
done

echo "$(basename "$tarball") passed"
