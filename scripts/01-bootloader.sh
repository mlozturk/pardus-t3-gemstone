#!/bin/bash
# T3 Gemstone O1 (TI AM67A / J722S) bootloader build
# BeagleY-AI Debian bootloader flow: R5 U-Boot (tiboot3.bin) -> TF-A + OP-TEE + A53 U-Boot (tispl.bin, u-boot.img)
set -euo pipefail
TOP=${TOP:-$(cd "$(dirname "$0")/.." && pwd)}
. "$TOP/versions.env"
OUT=$TOP/out/boot
JOBS=${JOBS:-$(nproc)}
CC32=$TOP/gcc-$GCC_VERSION-nolibc/arm-linux-gnueabi/bin/arm-linux-gnueabi-
CC64=$TOP/gcc-$GCC_VERSION-nolibc/aarch64-linux/bin/aarch64-linux-
FW=$TOP/ti-linux-firmware
# non-root build tree (03-rootfs-image.sh runs as root and owns $TOP/build)
B=${BUILD:-$TOP/build-user}
mkdir -p "$OUT" "$B"
cd "$TOP"

echo "### [1/4] TF-A (BL31)"
make -C trusted-firmware-a -j"$JOBS" CROSS_COMPILE="$CC64" ARCH=aarch64 \
     PLAT=k3 TARGET_BOARD=lite SPD=opteed CFLAGS= LDFLAGS= \
     BUILD_BASE="$B/tfa" all
BL31=$(ls "$B"/tfa/k3/lite/release/bl31.bin)

echo "### [2/4] OP-TEE (BL32)"
make -C optee_os -j"$JOBS" CROSS_COMPILE="$CC32" CROSS_COMPILE64="$CC64" \
     CFLAGS= LDFLAGS= PLATFORM=k3-am62x CFG_ARM64_core=y CFG_WITH_SOFTWARE_PRNG=y \
     O="$B/optee" all
TEE=$B/optee/core/tee-pager_v2.bin

echo "### [3/4] R5 SPL -> tiboot3.bin"
make -C u-boot O="$B/uboot-r5" ARCH=arm CROSS_COMPILE="$CC32" am67a_t3_gem_o1_r5_defconfig
make -C u-boot O="$B/uboot-r5" ARCH=arm CROSS_COMPILE="$CC32" -j"$JOBS" \
     BINMAN_INDIRS="$FW"

echo "### [4/4] A53 SPL + U-Boot -> tispl.bin, u-boot.img"
make -C u-boot O="$B/uboot-a53" ARCH=arm CROSS_COMPILE="$CC64" am67a_t3_gem_o1_a53_defconfig
make -C u-boot O="$B/uboot-a53" ARCH=arm CROSS_COMPILE="$CC64" -j"$JOBS" \
     BL31="$BL31" TEE="$TEE" BINMAN_INDIRS="$FW"

# HS-FS silicon is the production default for AM67A boards
R5B=$B/uboot-r5
if [ -f "$R5B/tiboot3-j722s-hs-fs-evm.bin" ]; then cp -v "$R5B/tiboot3-j722s-hs-fs-evm.bin" "$OUT/tiboot3.bin"; else cp -v "$R5B/tiboot3.bin" "$OUT/tiboot3.bin"; fi
cp -v "$R5B"/tiboot3-*.bin "$OUT/" 2>/dev/null || true
A53B=$B/uboot-a53
cp -v "$A53B/tispl.bin" "$A53B/u-boot.img" "$OUT/"
ls -la "$OUT"
echo BOOTLOADER_OK
