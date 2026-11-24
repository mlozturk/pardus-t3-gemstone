#!/bin/bash
# T3 Gemstone O1 kernel (t3gemstone/linux v6.12.24-ti-arm64-r43-t3-gem-o1) -> Debian .deb packages + boot files
set -euo pipefail
TOP=${TOP:-$(cd "$(dirname "$0")/.." && pwd)}
. "$TOP/versions.env"
OUT=$TOP/out
JOBS=${JOBS:-$(nproc)}
CC64=$TOP/gcc-$GCC_VERSION-nolibc/aarch64-linux/bin/aarch64-linux-
# non-root build tree (03-rootfs-image.sh runs as root and owns $TOP/build)
B=${BUILD:-$TOP/build-user}
KB=$B/linux
mkdir -p "$KB" "$OUT/kernel" "$OUT/boot/overlays"
cd "$TOP/linux"
export ARCH=arm64 CROSS_COMPILE="$CC64" KBUILD_BUILD_USER=gemstone KBUILD_BUILD_HOST=builder
make O="$KB" t3_gem_o1_defconfig
# Debian rootfs requirements (btrfs root, initramfs, systemd)
scripts/config --file "$KB/.config" -e BTRFS_FS -e BTRFS_FS_POSIX_ACL -e BLK_DEV_INITRD -e DEVTMPFS -e DEVTMPFS_MOUNT \
  -e CGROUPS -e AUTOFS_FS -e TMPFS_POSIX_ACL -e FHANDLE -e SECCOMP -d MODULE_SIG_ALL -d DEBUG_INFO_BTF \
  --set-str SYSTEM_TRUSTED_KEYS "" --set-str SYSTEM_REVOCATION_KEYS "" --set-str LOCALVERSION "-t3-gem-o1"
make O="$KB" olddefconfig
make O="$KB" -j"$JOBS" Image modules dtbs
make O="$KB" -j"$JOBS" bindeb-pkg KDEB_PKGVERSION=1gemstone DPKG_FLAGS=-d
# keep only this build's packages (03 installs the newest linux-image-*.deb it finds)
rm -f "$OUT"/kernel/linux-*.deb "$OUT"/kernel/linux-upstream*.buildinfo "$OUT"/kernel/linux-upstream*.changes
mv -v "$B"/linux-*.deb "$B"/linux-upstream*.buildinfo "$B"/linux-upstream*.changes "$OUT/kernel/" 2>/dev/null || true
mv -v "$TOP"/linux-*.deb "$OUT/kernel/" 2>/dev/null || true
cp -v "$KB/arch/arm64/boot/Image" "$OUT/boot/"
cp -v "$KB/arch/arm64/boot/dts/ti/k3-am67a-t3-gem-o1.dtb" "$OUT/boot/"
cp -v "$KB"/arch/arm64/boot/dts/ti/k3-am67a-t3-gem-o1-*.dtbo "$OUT/boot/overlays/"
make -s O="$KB" kernelrelease > "$OUT/kernel/release"
ls -la "$OUT/kernel" "$OUT/boot"
echo KERNEL_OK
