#!/bin/bash
# T3 Gemstone O1: the whole build with one command. Run as your normal user, from anywhere;
# only the image step needs root and asks for it with sudo.
#
#   ./build.sh desktop                Pardus 25 "lite" (XFCE) + 6.18 LTS kernel with the HDMI patches
#   ./build.sh headless               Pardus 25 "minimal" (no desktop) + mainline kernel, no patches
#   ./build.sh image --flavor full|lite|minimal --kernel <kernel>   any combination
#   --kernel also changes desktop/headless, e.g. ./build.sh desktop --kernel stable-hdmi
#     lts-hdmi  6.18 LTS + HDMI patches (desktop default)   mainline  6.18 LTS, no patches (headless default)
#     stable-hdmi  7.3 stable + HDMI patches               stable    7.3 stable, no patches
#     debian  Debian 7.2.12 + HDMI patches                 t3        T3's 6.12
#
# Options:
#   --release VERSION   compress harder (xz -6) and collect the image into release/VERSION/
#                       with SHA256SUMS and the release notes (scripts/06-release.sh)
#   --rebuild-kernel    build the kernel again even if a package already exists
#   --distro debian     Debian 13 instead of Pardus 25
#   --xz N              xz level of the .img.xz (default 3)
#
# Steps, each skipped when its result already exists: sources (00) -> bootloader (01) ->
# kernel (02 or kernels/<name>/build.sh; the board DTB is always rebuilt, it takes seconds) ->
# rootfs + SD image (03, sudo). Logs: out-<flavor>-<kernel>.log. Then: scripts/04-flash-sd.sh.
set -euo pipefail
TOP=$(cd "$(dirname "$0")" && pwd)
cd "$TOP"
[ "$(id -u)" != 0 ] || { echo "run as your normal user (not with sudo): only the image step needs root and asks for it"; exit 1; }
. "$TOP/versions.env"

MODE=${1:-}; [ $# -gt 0 ] && shift
case "$MODE" in
  desktop)  FLAVOR=lite;    KERNEL=lts-hdmi ;;
  headless) FLAVOR=minimal; KERNEL=mainline ;;
  image)    FLAVOR=;        KERNEL= ;;
  *) sed -n '2,/^set -euo/p' "$0" | sed '$d'; exit 1 ;;
esac
DISTRO=pardus; RELEASE=; REBUILD=0; XZ=3
while [ $# -gt 0 ]; do
  case "$1" in
    --flavor) FLAVOR=${2:?}; shift 2 ;;
    --kernel) KERNEL=${2:?}; shift 2 ;;
    --distro) DISTRO=${2:?}; shift 2 ;;
    --release) RELEASE=${2:?release version, e.g. 2026.11}; XZ=6; shift 2 ;;
    --rebuild-kernel) REBUILD=1; shift ;;
    --xz) XZ=${2:?}; shift 2 ;;
    *) echo "unknown option: $1"; exit 1 ;;
  esac
done
case "$FLAVOR" in full|lite|minimal) ;; *) echo "--flavor must be full, lite or minimal"; exit 1 ;; esac
case "$KERNEL" in t3|debian|mainline|lts-hdmi|stable|stable-hdmi) ;;
  *) echo "--kernel must be lts-hdmi, mainline, stable-hdmi, stable, debian or t3"; exit 1 ;; esac
case "$KERNEL" in mainline|stable)
  if [ "$FLAVOR" != minimal ]; then echo "note: the $KERNEL kernel has no HDMI; the desktop will not show on a screen"; fi ;;
esac
step(){ echo; echo "=== $*"; }

step "1/4 sources"
if [ ! -x "gcc-$GCC_VERSION-nolibc/aarch64-linux/bin/aarch64-linux-gcc" ] || [ ! -d u-boot/.git ] || [ ! -d ti-linux-firmware/.git ]; then
  ./scripts/00-fetch-sources.sh
else echo "present"; fi

step "2/4 bootloader"
if [ ! -f out/boot/u-boot.img ] || [ ! -f out/boot/tispl.bin ] || [ ! -f out/boot/tiboot3.bin ]; then
  ./scripts/01-bootloader.sh 2>&1 | tee out-bootloader.log
else echo "present (out/boot; delete it to rebuild)"; fi

step "3/4 kernel: $KERNEL"
case "$KERNEL" in
  t3)
    if [ "$REBUILD" = 1 ] || ! ls out/kernel/linux-image-*.deb >/dev/null 2>&1; then
      ./scripts/02-kernel.sh 2>&1 | tee out-kernel.log
    else echo "present: $(cat out/kernel/release)"; fi ;;
  *)
    if [ "$REBUILD" = 1 ] || ! ls "kernels/$KERNEL/out"/linux-image-*.deb >/dev/null 2>&1; then
      "kernels/$KERNEL/build.sh"
    else
      echo "present: $(cat "kernels/$KERNEL/out/release")"
      DTB_ONLY=1 "kernels/$KERNEL/build.sh"     # board/dts may have changed
    fi ;;
esac

step "4/4 rootfs + image: $DISTRO $FLAVOR, kernel $KERNEL (sudo)"
LOG=out-$FLAVOR-$KERNEL.log
sudo "$TOP/scripts/03-rootfs-image.sh" --distro "$DISTRO" --flavor "$FLAVOR" --kernel "$KERNEL" --xz "$XZ" 2>&1 | tee "$LOG"
IMG=$(sed -n 's/^IMAGE_OK //p' "$LOG" | tail -1)
[ -n "$IMG" ] || { echo "no IMAGE_OK in $LOG"; exit 1; }

if [ -n "$RELEASE" ]; then
  step "release $RELEASE"
  ./scripts/06-release.sh "$RELEASE" "$IMG.xz"
fi
echo
echo "BUILD_OK $IMG.xz"
echo "write it to a card: sudo ./scripts/04-flash-sd.sh /dev/sdX $(basename "$IMG.xz")"
