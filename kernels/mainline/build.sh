#!/bin/bash
# Mainline kernel for the T3 Gemstone O1: kernel.org Linux, unmodified, small ("lite") config.
#
#   - source: kernel.org longterm (LTS) tarball, version + checksum in versions.env, NOT patched
#   - config: mainline arm64 defconfig, every non-TI SoC family switched off, plus the few board
#             drivers defconfig leaves out (Wi-Fi/BT RTL8822CS, humidity sensor, CAN PHY ...),
#             display (DSS/HDMI) and sound off: the display subsystem of this SoC is not in mainline
#   - board DTS: board/dts/k3-am67a-t3-gem-o1-headless.dts (the board is not in mainline; same
#             source as the Debian kernel, without the display part); compiled next to the tree
#             with cpp + dtc, the kernel source itself is not touched
#   -> kernels/mainline/out/{linux-image-*.deb, Image, k3-am67a-t3-gem-o1.dtb, release}
#
# VARIANT=hdmi (what kernels/lts-hdmi/build.sh runs): the same LTS tarball + the HDMI patches of
#   kernels/lts-hdmi/patches (Tomi Valkeinen's tidss/AM62P series, ported to 6.18), display and
#   HDMI audio on, board DTS with the display part -> kernels/lts-hdmi/out/ ("-gemstone-hdmi")
#
# Usage:  kernels/mainline/build.sh              (no root needed; ~10 min on 4 vCPU)
#         PREP_ONLY=1 kernels/mainline/build.sh  (only download + unpack)
#         DTB_ONLY=1  kernels/mainline/build.sh  (only rebuild the board DTB after a board/dts change)
# Then:   ./build.sh headless                     (minimal image with this kernel)
# Versions: versions.env (MAINLINE_*)
set -euo pipefail
TOP=${TOP:-$(cd "$(dirname "$0")/../.." && pwd)}
. "$TOP/versions.env"
VARIANT=${VARIANT:-plain}
# TRACK=lts (default): kernel.org longterm 6.18 (versions.env MAINLINE_*)
#   -> kernels/mainline (plain), kernels/lts-hdmi (hdmi)
# TRACK=stable: kernel.org stable 7.3 (versions.env STABLE_*), what kernels/stable*/build.sh run
#   -> kernels/stable (plain), kernels/stable-hdmi (hdmi)
TRACK=${TRACK:-lts}
case "$TRACK" in
  lts)    V=$MAINLINE_VERSION; SHA256=$MAINLINE_SHA256; PKGVER=$MAINLINE_PKGVER
          PLAIN_DIR=mainline; HDMI_DIR=lts-hdmi; PLAIN_LV=-gemstone-mainline; HDMI_LV=-gemstone-hdmi ;;
  stable) V=$STABLE_VERSION; SHA256=$STABLE_SHA256; PKGVER=$STABLE_PKGVER
          PLAIN_DIR=stable; HDMI_DIR=stable-hdmi; PLAIN_LV=-gemstone-stable; HDMI_LV=-gemstone-stable-hdmi ;;
  *) echo "TRACK must be lts or stable"; exit 1 ;;
esac
# both tracks are older than 7.4, so both board DTS variants take the GPU/VPU nodes from gpu-v7.4.dtsi
case "$VARIANT" in
  plain) K=${K:-$TOP/kernels/$PLAIN_DIR}; DTSNAME=k3-am67a-t3-gem-o1-headless.dts; LV=$PLAIN_LV ;;
  hdmi)  K=${K:-$TOP/kernels/$HDMI_DIR}; DTSNAME=k3-am67a-t3-gem-o1-lts-hdmi.dts; LV=$HDMI_LV
         PATCHES=$K/patches
         ls "$PATCHES"/0*.patch >/dev/null 2>&1 || { echo "no patches in $PATCHES"; exit 1; } ;;
  *) echo "VARIANT must be plain or hdmi"; exit 1 ;;
esac
SRC=$K/src; O=$K/build; OUTD=$K/out
TARD=$TOP/kernels/mainline      # the tarball is shared by both variants
CC=${CC:-$TOP/gcc-$GCC_VERSION-nolibc/aarch64-linux/bin/aarch64-linux-}
# the prepared tree is tied to the version and (hdmi) to the exact patch set: change either and
# the source is unpacked and patched again
STAMP=.unpacked-$V
[ "$VARIANT" = hdmi ] && STAMP=.prepared-$V-$(cat "$PATCHES"/0*.patch | sha256sum | cut -c1-12)
mkdir -p "$K" "$O" "$OUTD" "$TARD"
cd "$K"

build_dtb() {   # board DTB, named as U-Boot loads it
  local dtc=dtc; [ -x "$O/scripts/dtc/dtc" ] && dtc=$O/scripts/dtc/dtc
  "$TOP/board/dts/build-dtb.sh" "$SRC" "$DTSNAME" "$OUTD/k3-am67a-t3-gem-o1.dtb" "$dtc"
}
if [ "${DTB_ONLY:-0}" = 1 ]; then
  [ -f "$SRC/$STAMP" ] || { echo "no prepared kernel source yet: run the build once"; exit 1; }
  build_dtb; echo DTB_OK; exit 0
fi

# --- 1) source: pristine kernel.org tarball -------------------------------------------------------
cd "$TARD"
T=linux-$V.tar.xz
if [ ! -s "$T" ] || ! echo "$SHA256  $T" | sha256sum -c --quiet - >/dev/null 2>&1; then
  wget -q "https://cdn.kernel.org/pub/linux/kernel/v${V%%.*}.x/$T" -O "$T"
  echo "$SHA256  $T" | sha256sum -c --quiet - >/dev/null 2>&1 || { echo "checksum mismatch: $T"; exit 1; }
fi
# unpack into a temporary dir and rename at the end: an interrupted unpack (e.g. a VM freeze) must
# not leave a half-filled tree that later looks complete (it happened: empty headers, odd link errors)
if [ ! -f "$SRC/$STAMP" ]; then
  rm -rf "$SRC" "$SRC.tmp"; mkdir -p "$SRC.tmp"
  tar -xf "$TARD/$T" -C "$SRC.tmp" --strip-components=1
  if [ "$VARIANT" = hdmi ]; then
    # a git tree, so the applied patches stay visible (git log v$V..HEAD)
    ( cd "$SRC.tmp"
      git init -q; git add -A -f
      git -c user.name=gemstone -c user.email=gemstone@localhost commit -q -m "kernel.org linux-$V"
      git tag "v$V"
      git -c user.name=gemstone -c user.email=gemstone@localhost am -q "$PATCHES"/0*.patch
      echo "source ready: $(git log --oneline "v$V"..HEAD | wc -l) HDMI patches on top of $V" )
  fi
  touch "$SRC.tmp/$STAMP"; mv "$SRC.tmp" "$SRC"
  rm -rf "$O"; mkdir -p "$O"
fi
cd "$K"
[ "${PREP_ONLY:-0}" = 1 ] && { echo PREP_OK; exit 0; }

# --- 2) config ------------------------------------------------------------------------------------
cd "$SRC"
make -s O="$O" ARCH=arm64 CROSS_COMPILE="$CC" defconfig
S="scripts/config --file $O/.config"
# only TI K3 SoCs: switch every other arm64 platform off (most of defconfig's modules are theirs)
for a in $(sed -n 's/^config \(ARCH_[A-Z0-9_]*\)$/\1/p' arch/arm64/Kconfig.platforms); do
  case "$a" in ARCH_K3) ;; *) $S -d "$a" ;; esac
done
if [ "$VARIANT" = plain ]; then
  # display subsystem / HDMI / audio: not supported by mainline on this SoC, and not wanted here
  $S -d DRM_TIDSS -d DRM_SII902X -d SOUND -d SND
else
  # hdmi: display unit (tidss, with the patches), SiI9022 HDMI bridge, HDMI connector, DSI PHY;
  # HDMI audio: McASP + its DMA glue, simple-audio-card, the bridge's hdmi-codec; USB audio
  $S -m DRM_TIDSS -m DRM_SII902X -m DRM_DISPLAY_CONNECTOR -m PHY_CADENCE_DPHY \
     -e SOUND -m SND -m SND_SOC -m SND_SOC_DAVINCI_MCASP -m SND_SOC_TI_UDMA_PCM \
     -m SND_SOC_TI_EDMA_PCM -m SND_SOC_TI_SDMA_PCM -m SND_SIMPLE_CARD -m SND_SOC_HDMI_CODEC \
     -m SND_USB_AUDIO
  # text console on HDMI until the desktop starts
  $S -e DRM_FBDEV_EMULATION -e FRAMEBUFFER_CONSOLE
fi
# big PCIe/desktop GPU and NIC drivers defconfig carries for servers and PCs
$S -d DRM_NOUVEAU -d DRM_AMDGPU -d DRM_RADEON -d DRM_HISI_HIBMC -d MLX4_CORE -d MLX5_CORE \
   -d IXGBE -d IGB -d E1000E -d BNX2X -d CHELSIO_T4 -d HNS3
# board: root on btrfs (built in, so the initramfs needs no module for it), SD/eMMC, PMIC, GPU
$S -e BTRFS_FS -e BTRFS_FS_POSIX_ACL -e MMC_SDHCI_AM654 -e MFD_TPS65219 -e REGULATOR_TPS65219 \
   -m INPUT_TPS65219_PWRBUTTON -m DRM_POWERVR
# board: Wi-Fi + Bluetooth (Realtek RTL8822CS on SDIO / UART)
$S -m RTW88 -m RTW88_8822CS -e SERIAL_DEV_BUS -m BT_HCIUART -e BT_HCIUART_SERDEV -e BT_HCIUART_RTL \
   -e BT_HCIUART_3WIRE -m BT_RTL
# board: Ethernet, CAN, sensors, fan, watchdog, DSPs, video/JPEG codecs, PCIe, USB
$S -m TI_K3_AM65_CPSW_NUSS -m TI_DAVINCI_MDIO -m PHY_TI_GMII_SEL -m DP83867_PHY \
   -m CAN_M_CAN -m CAN_M_CAN_PLATFORM -m PHY_CAN_TRANSCEIVER -m HDC2010 -m PWM_TIEHRPWM \
   -m K3_RTI_WATCHDOG -m TI_K3_DSP_REMOTEPROC -m TI_K3_R5_REMOTEPROC -m VIDEO_WAVE_VPU \
   -m VIDEO_E5010_JPEG_ENC -m PCI_J721E_HOST -m USB_CDNS3 -m USB_CDNS3_TI -m RTC_DRV_TI_K3
# systemd + Debian initramfs-tools needs
$S -e DEVTMPFS -e DEVTMPFS_MOUNT -e BLK_DEV_INITRD -e RD_GZIP -e RD_ZSTD -e CGROUPS -e AUTOFS_FS \
   -e TMPFS_POSIX_ACL -e FHANDLE -e SECCOMP
# small and quick: no debug info
$S -d DEBUG_INFO -d DEBUG_INFO_DWARF5 -d DEBUG_INFO_DWARF4 -d DEBUG_INFO_DWARF_TOOLCHAIN_DEFAULT \
   -e DEBUG_INFO_NONE -d DEBUG_INFO_BTF
$S --set-str LOCALVERSION "$LV" -d LOCALVERSION_AUTO
make -s O="$O" ARCH=arm64 CROSS_COMPILE="$CC" olddefconfig
echo "modules: $(grep -c '=m$' "$O/.config")   built-in: $(grep -c '=y$' "$O/.config")"
if [ "$VARIANT" = hdmi ]; then   # olddefconfig silently drops what Kconfig refuses: say it
  for k in DRM_TIDSS DRM_SII902X SND_SOC_DAVINCI_MCASP SND_SIMPLE_CARD SND_SOC_HDMI_CODEC; do
    grep -q "^CONFIG_$k=[ym]" "$O/.config" || echo "WARNING: CONFIG_$k is not set"
  done
fi

# --- 3) .deb + board DTB ----------------------------------------------------------------------------
echo "### build start $(date)"
make O="$O" ARCH=arm64 CROSS_COMPILE="$CC" -j"$(nproc)" KDEB_PKGVERSION=$PKGVER DPKG_FLAGS=-d \
     DEB_BUILD_PROFILES="pkg.linux-upstream.nokernelheaders pkg.linux-upstream.nokerneldbg" bindeb-pkg > "$K/make.log" 2>&1 \
  || { grep -E 'error|Error' "$K/make.log" | tail -30; exit 1; }
rm -f "$OUTD"/linux-*.deb
mv -f "$K"/linux-*.deb "$OUTD/" 2>/dev/null || mv -f "$O"/../linux-*.deb "$OUTD/" 2>/dev/null || true
cp "$O/arch/arm64/boot/Image" "$OUTD/"
# board DTB from board/dts, against this tree's SoC .dtsi files (nothing is copied into the tree)
build_dtb
cat "$O/include/config/kernel.release" > "$OUTD/release"
ls -la "$OUTD"
echo "### build end $(date)"
echo "$(echo "$TRACK-$VARIANT" | tr 'a-z-' 'A-Z_')_KERNEL_OK"     # e.g. LTS_HDMI_KERNEL_OK, STABLE_PLAIN_KERNEL_OK
[ "$TRACK-$VARIANT" = lts-plain ] && echo MAINLINE_KERNEL_OK || true
