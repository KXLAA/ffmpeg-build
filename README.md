# ffmpeg-build

Small static LGPL builds of [FFmpeg](https://ffmpeg.org) for [Cratebase](https://github.com/KXLAA/cratebase). They decode every audio format Cratebase imports and encode the formats it transcodes to. Everything else is left out: video, networking, devices, and any library that happens to be installed on the build machine.

The scripts started as a fork of [acoustid/ffmpeg-build](https://github.com/acoustid/ffmpeg-build).

## Releases

Each release, tagged `v<ffmpeg version>-<build>`, has one `ffmpeg-<version>-<platform>.tar.gz` per platform plus a `SHA256SUMS` file. Each tarball holds:

- `ffmpeg` (`ffmpeg.exe` on Windows)
- `LICENSE.LGPL`
- `BUILD.txt`: the sources, their checksums and the configure flags

Platforms are named as Node names them:

| Platform | Built | Runs on |
| --- | --- | --- |
| `darwin-arm64`, `darwin-x64` | clang on macOS, `-target <arch>-apple-macos13` | macOS 13+ |
| `linux-x64`, `linux-arm64` | Alpine (musl), fully static | any Linux |
| `win32-x64` | mingw-w64 on Ubuntu | Windows 10+, and Windows on Arm under emulation |

What's in it:

- Decoders: AAC, ALAC, FLAC, MP3, Opus, Vorbis, WMA and PCM.
- Containers it reads: ADTS, AIFF, ASF, FLAC, Matroska/WebM, MP4/M4A, MP3, Ogg and WAV.
- Encoders: AAC, ALAC, FLAC, MP3 (LAME) and PCM.
- Containers it writes: ADTS, AIFF, FLAC, M4A, MP3, MP4 and WAV.

`common.sh` has the exact list.

## Building

```sh
PLATFORM=darwin-arm64 ./build-macos.sh   # any Mac, either architecture (darwin-x64 needs nasm)
PLATFORM=linux-arm64 ./build-linux.sh    # in Docker, on a host of that architecture
PLATFORM=win32-x64 ./build-windows.sh    # on Linux with mingw-w64 and nasm
./smoke-test.sh dist/ffmpeg-8.1.2-darwin-arm64.tar.gz
```

`smoke-test.sh` runs on the platform the tarball is for. It checks four things:

- The version is the pinned one.
- The binary links nothing outside the OS.
- Every file in `fixtures/` decodes with Cratebase's command.
- Each encoder's output reads back.

CI (`.github/workflows/build.yml`) builds every platform and smoke-tests each on a native runner. On a `v*` tag it also publishes the release.

## Updating FFmpeg

1. In `common.sh`, set `FFMPEG_VERSION` and `FFMPEG_SHA256`. Take the checksum from a tarball whose `.asc` signature verifies against FFmpeg's release key (`FCF986EA15E6E293A5644F10B4322F04D67658D8`).
2. Push, and once CI passes, tag `v<version>-1`.
3. In Cratebase, pin the new release and its `SHA256SUMS` in `apps/server/scripts/fetch-ffmpeg.ts`.

To support a new format, add its demuxer, decoder and parser in `common.sh`, and a fixture in `make-fixtures.sh`.

## License

The scripts are MIT. The binaries are LGPL-2.1-or-later: FFmpeg is configured without `--enable-gpl` or `--enable-nonfree`, and LAME is LGPL. `BUILD.txt` in each tarball links the exact sources.
