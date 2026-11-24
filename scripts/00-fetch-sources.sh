#!/bin/bash
# T3 Gemstone O1: download the cross compilers and every source tree at the exact commit this
# project was built and tested with, then apply our kernel patch. Safe to run again.
# Run as a normal user (no sudo) from anywhere: ./scripts/00-fetch-sources.sh
set -euo pipefail
TOP=${TOP:-$(cd "$(dirname "$0")/.." && pwd)}
cd "$TOP"
. "$TOP/versions.env"      # all pinned versions

# ---- cross compilers (kernel.org crosstool, no libc) -> gcc-<version>-nolibc/
GCC=$GCC_VERSION
URL=https://mirrors.edge.kernel.org/pub/tools/crosstool/files/bin/x86_64/$GCC
for t in aarch64-linux arm-linux-gnueabi; do
  if [ ! -x "gcc-$GCC-nolibc/$t/bin/$t-gcc" ]; then
    echo "### compiler $t"
    wget -nc -q --show-progress "$URL/x86_64-gcc-$GCC-nolibc-$t.tar.xz"
    tar xf "x86_64-gcc-$GCC-nolibc-$t.tar.xz"
  fi
done

# ---- sources: <dir> <git url> <branch or tag> <exact commit>  (values from versions.env)
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
# shellcheck disable=SC2086   (each variable holds "url ref commit")
fetch u-boot             $UBOOT
fetch linux              $T3_LINUX
fetch trusted-firmware-a $TFA
fetch optee_os           $OPTEE
fetch ti-linux-firmware  $TI_FIRMWARE

# ---- our kernel patches (skipped if already applied)
for p in patches/linux-*.patch; do
  if git -C linux apply -R --check "$TOP/$p" 2>/dev/null; then
    echo "    patch already applied: $p"
  else
    echo "### apply $p"; git -C linux apply "$TOP/$p"
  fi
done
# The Debian and mainline kernels download their own (pinned) sources: kernels/*/build.sh
echo SOURCES_OK
