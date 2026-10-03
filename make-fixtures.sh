#!/usr/bin/env bash
# Writes fixtures/: a second of stereo tone in every format Cratebase imports, for smoke-test.sh.
# Needs a full ffmpeg build (FFMPEG=/path/to/ffmpeg, or the one on PATH). The output is committed.

set -euo pipefail

cd "$(dirname "$0")"
ffmpeg=${FFMPEG:-ffmpeg}
mkdir -p fixtures

fixture() {
    local file=$1
    shift
    "$ffmpeg" -hide_banner -loglevel error -y \
        -f lavfi -i "aevalsrc=0.5*sin(2*PI*440*t)|0.5*sin(2*PI*660*t):d=1:s=44100" \
        -map_metadata -1 -fflags +bitexact -flags:a +bitexact "$@" "fixtures/$file"
}

fixture tone.mp3 -codec:a libmp3lame -b:a 128k
fixture tone.aac -codec:a aac -b:a 128k
fixture tone.m4a -codec:a aac -b:a 128k
fixture tone.mp4 -codec:a aac -b:a 128k
fixture tone-alac.m4a -codec:a alac
fixture tone.alac -codec:a alac -f ipod
fixture tone.flac -codec:a flac
fixture tone.ogg -codec:a libvorbis
fixture tone.opus -codec:a libopus
fixture tone.webm -codec:a libopus
fixture tone.wma -codec:a wmav2
fixture tone.wav -codec:a pcm_s16le
fixture tone-s24.wav -codec:a pcm_s24le
fixture tone-f32.wav -codec:a pcm_f32le
fixture tone.aiff -codec:a pcm_s16be
fixture tone-s24.aif -codec:a pcm_s24be
