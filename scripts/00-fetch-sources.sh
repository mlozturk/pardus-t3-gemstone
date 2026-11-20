#!/bin/bash
# T3 Gemstone O1: download the cross compilers and every source tree at the exact commit this
# project was built and tested with, then apply our kernel patch. Safe to run again.
# Run as a normal user (no sudo) from anywhere: ./scripts/00-fetch-sources.sh
set -euo pipefail
TOP=${TOP:-$(cd "$(dirname "$0")/.." && pwd)}
cd "$TOP"

# ---- cross compilers (kernel.org crosstool, GCC 11.5.0, no libc) -> gcc-11.5.0-nolibc/
GCC=11.5.0
URL=https://mirrors.edge.kernel.org/pub/tools/crosstool/files/bin/x86_64/$GCC
for t in aarch64-linux arm-linux-gnueabi; do
  if [ ! -x "gcc-$GCC-nolibc/$t/bin/$t-gcc" ]; then
    echo "### compiler $t"
    wget -nc -q --show-progress "$URL/x86_64-gcc-$GCC-nolibc-$t.tar.xz"
    tar xf "x86_64-gcc-$GCC-nolibc-$t.tar.xz"
  fi
done

# ---- sources: <dir> <git url> <branch or tag> <exact commit>
fetch(){
  local dir=$1 url=$2 ref=$3 sha=$4
  if [ ! -d "$dir/.git" ]; then
    echo "### clone $dir ($ref)"
    git clone -q --depth 1 -b "$ref" "$url" "$dir"
  fi
  if [ "$(git -C "$dir" rev-parse HEAD)" != "$sha" ]; then
    git -C "$dir" fetch -q --depth 1 origin "$sha"
    git -C "$dir" checkout -q "$sha"
  fi
  echo "    $dir @ $(git -C "$dir" rev-parse --short HEAD)"
}
fetch u-boot             https://github.com/t3gemstone/u-boot.git              v2025.04-rc3-t3-gem-o1          b8410d78120ed91156f3ec7ede81bed004f8b46e
fetch linux              https://github.com/t3gemstone/linux.git               v6.12.24-ti-arm64-r43-t3-gem-o1 6267aeaee46f09c9550cf135c6041970c973d7c0
fetch trusted-firmware-a https://github.com/TrustedFirmware-A/trusted-firmware-a.git lts-v2.12.4           a9fcaf3ccf3c0091c33ba6ef03b8ed629394c240
fetch optee_os           https://github.com/OP-TEE/optee_os.git                4.6.0                           71785645fa6ce42db40dbf5a54e0eaedc4f61591
fetch ti-linux-firmware  https://github.com/beagleboard/ti-linux-firmware.git  11.01.03                        e594deb508a322d5681888d48fbb153953b06ca9

# ---- our kernel patches (skipped if already applied)
for p in patches/linux-*.patch; do
  if git -C linux apply -R --check "$TOP/$p" 2>/dev/null; then
    echo "    patch already applied: $p"
  else
    echo "### apply $p"; git -C linux apply "$TOP/$p"
  fi
done
echo SOURCES_OK
