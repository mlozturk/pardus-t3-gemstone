#!/bin/bash
# Debian kernel for the T3 Gemstone O1.
#
#   Debian's own kernel source (linux 7.2.12-1~bpo13+1, trixie-backports)
#   + the HDMI (tidss / AM62P display) patches that are not in Debian or mainline yet
#   + Debian's own arm64 config, with the few TI/board options Debian leaves off
#   + the board description from board/dts/ (k3-am67a-t3-gem-o1.dts, with HDMI), compiled next to
#     the tree: the same source the mainline kernel uses
#   -> linux-image-7.2.12-gemstone+_7.2.12-1gemstone1_arm64.deb, Image, DTB   (in kernels/debian/out/)
#
# Usage:  kernels/debian/build.sh              (no root needed; ~60-90 min on 4 vCPU)
#         PREP_ONLY=1 kernels/debian/build.sh  (only download + patch the source)
#         DTB_ONLY=1  kernels/debian/build.sh  (only rebuild the board DTB after a board/dts change; seconds)
# Then:   ./build.sh desktop                    (new SD image with this kernel)
#    or:  scripts/05-kernel-deploy.sh <board-ip> (update a running board over SSH)
# Versions: versions.env (DEBIAN_KERNEL_*)
set -euo pipefail
TOP=${TOP:-$(cd "$(dirname "$0")/../.." && pwd)}
. "$TOP/versions.env"
K=${K:-$TOP/kernels/debian}
SRC=$K/src; O=$K/build; OUTD=$K/out
CC=${CC:-$TOP/gcc-$GCC_VERSION-nolibc/aarch64-linux/bin/aarch64-linux-}
DEBVER=$DEBIAN_KERNEL_DEBVER
ABI=$DEBIAN_KERNEL_ABI
PKGVER=$DEBIAN_KERNEL_PKGVER
MIRROR=${MIRROR:-https://deb.debian.org/debian}
SNAPSHOT=${SNAPSHOT:-https://snapshot.debian.org/file}
mkdir -p "$K" "$O" "$OUTD"
cd "$K"

# board DTB from board/dts against this tree (also used alone with DTB_ONLY=1)
build_dtb() {
  local dtc=dtc; [ -x "$O/scripts/dtc/dtc" ] && dtc=$O/scripts/dtc/dtc
  "$TOP/board/dts/build-dtb.sh" "$SRC" k3-am67a-t3-gem-o1.dts "$OUTD/k3-am67a-t3-gem-o1.dtb" "$dtc"
}
if [ "${DTB_ONLY:-0}" = 1 ]; then
  [ -d "$SRC/.git" ] || { echo "no kernel source yet: run kernels/debian/build.sh once"; exit 1; }
  build_dtb; echo DTB_OK; exit 0
fi

# Pinned Debian files (versions.env): name, sha1 (snapshot.debian.org address), sha256 (check).
# deb.debian.org keeps only the newest backports version; once 7.2.12 is replaced there, the same
# files are still served by snapshot.debian.org by their sha1, so the build stays reproducible.
PINNED=$DEBIAN_KERNEL_PINNED
fetch() {   # fetch <file>: pool first, snapshot.debian.org second; always checked against sha256
  local f=$1 sha1 sha256
  read -r _ sha1 sha256 <<<"$(echo "$PINNED" | awk -v f="$f" '$1==f')"
  [ -n "$sha256" ] || { echo "not pinned: $f"; exit 1; }
  if [ -s "$f" ] && echo "$sha256  $f" | sha256sum -c --quiet - >/dev/null 2>&1; then return; fi
  wget -q "$MIRROR/pool/main/l/linux/$f" -O "$f" || true
  if ! echo "$sha256  $f" | sha256sum -c --quiet - >/dev/null 2>&1; then
    echo "$f: not on $MIRROR any more, using snapshot.debian.org"
    wget -q "$SNAPSHOT/$sha1" -O "$f"
    echo "$sha256  $f" | sha256sum -c --quiet - >/dev/null 2>&1 || { echo "checksum mismatch: $f"; exit 1; }
  fi
}

# --- 1) source: Debian's package source, unpacked with Debian's patches, as a git tree -----------
if [ ! -d "$SRC/.git" ]; then
  ls "$K"/patches/0*.patch >/dev/null 2>&1 || { echo "no patches in $K/patches (HDMI support lives there)"; exit 1; }
  for f in "linux_${DEBVER}.dsc" "linux_${DEBVER%%-*}.orig.tar.xz" "linux_${DEBVER}.debian.tar.xz"; do
    fetch "$f"
  done
  rm -rf "$SRC"
  dpkg-source -x "linux_${DEBVER}.dsc" "$SRC" > dpkg-source.log 2>&1
  cd "$SRC"
  git init -q; git checkout -q -b gemstone
  # -f: the kernel's own .gitignore would otherwise hide files from this baseline commit
  git add -A -f; git -c user.name=gemstone -c user.email=gemstone@localhost commit -q -m "Debian linux $DEBVER (debian/patches applied)"
  git tag debian-7.2.12
  # our patches: 0001-0022 HDMI (Tomi Valkeinen's series, see patches/README), 0023-0024 GPU and
  # VPU-SRAM nodes from mainline v7.4. The board DTS is not a patch: it lives in board/dts/.
  git -c user.name=gemstone -c user.email=gemstone@localhost am -q "$K"/patches/*.patch
  echo "source ready: $(git log --oneline debian-7.2.12..HEAD | wc -l) patches on top of Debian $DEBVER"
  cd "$K"
fi
[ "${PREP_ONLY:-0}" = 1 ] && { echo PREP_OK; exit 0; }

# --- 2) config: Debian's exact config for this kernel, from its official binary package ---------
if [ ! -s config-debian ]; then
  # Debian 7.x splits the image package; the config lives in linux-base-<abi>
  BASE=linux-base-${ABI}_${DEBVER}_arm64.deb
  fetch "$BASE"
  CF=$(dpkg-deb -c "$BASE" | awk '{print $6}' | grep -E '/config(-[^/]*)?$' | head -1)
  dpkg-deb --fsys-tarfile "$BASE" | tar -xO "$CF" > config-debian
fi
cp config-debian "$O/.config"
cd "$SRC"
S="scripts/config --file $O/.config"
# board needs: PMIC, humidity sensor
$S -e MFD_TPS65219 -e REGULATOR_TPS65219 -m HDC2010
# Debian 7.2's arm64 config leaves core TI K3 pieces off (arm64 defconfig has them). Without the
# interrupt routers GPIO interrupts fail -> the SD card's GPIO power switches never come up -> no root.
$S -e TI_SCI_INTR_IRQCHIP -e TI_SCI_INTA_IRQCHIP -e TI_SCI_INTA_MSI_DOMAIN \
   -e TI_K3_RINGACC -e TI_K3_PSIL -e TI_K3_UDMA -e TI_K3_UDMA_GLUE_LAYER -e TI_K3_CPPI_DESC_POOL \
   -m TI_K3_AM65_CPSW_NUSS -m TI_DAVINCI_MDIO -m PHY_TI_GMII_SEL -m DP83TG720_PHY \
   -m SND_SOC_DAVINCI_MCASP -m SND_SOC_TI_UDMA_PCM -m SND_SOC_TI_EDMA_PCM -m SND_SOC_TI_SDMA_PCM \
   -m DRM_CDNS_DSI -e DRM_CDNS_DSI_J721E -m PHY_CADENCE_DPHY -m PHY_CADENCE_DPHY_RX -m PHY_CADENCE_SIERRA \
   -m PHY_CADENCE_SALVO -m PHY_AM654_SERDES -m OMAP_USB2 -m RTC_DRV_TI_K3 \
   -m HWSPINLOCK_OMAP -m RESET_TI_SYSCON -m TI_K3_DSP_REMOTEPROC -m TI_K3_M4_REMOTEPROC \
   -m VIDEO_CADENCE_CSI2RX -m VIDEO_TI_J721E_CSI2RX -m DRM_TI_SN65DSI83 -m DRM_TI_TFP410 \
   -m INPUT_TPS65219_PWRBUTTON -m TI_EQEP -m I2C_CADENCE
# found missing in the first boot's dmesg: CAN transceiver, fan PWM (ehrpwm),
# JPEG encoder and video codec (their power domains kept sync_state pending)
$S -m PHY_CAN_TRANSCEIVER -m PWM_TIEHRPWM -m VIDEO_E5010_JPEG_ENC -m VIDEO_WAVE_VPU
# GPU: PowerVR BXS-4-64 (upstream drm/imagination driver; Debian leaves it off). Needs the
# firmware powervr/rogue_36.53.104.796_v1.fw (03 puts it into the rootfs) and Mesa >= 26
$S -m DRM_POWERVR
# SA2UL crypto accelerator: fails the crypto self-tests and oopses on J722S with this kernel -> off
$S -d CRYPTO_DEV_SA2UL
# Debian's panic screen is a QR code that needs Rust; we build without Rust
$S --set-str DRM_PANIC_SCREEN kmsg
# Debian's signing key is not ours: sign modules with a key generated at build time
# (certs/signing_key.pem) instead of leaving them unsigned (kernel taint "E")
$S -e MODULE_SIG -e MODULE_SIG_ALL -d MODULE_SIG_FORCE --set-str MODULE_SIG_KEY "certs/signing_key.pem" \
   --set-str SYSTEM_TRUSTED_KEYS "" --set-str SYSTEM_REVOCATION_KEYS ""
$S -d DEBUG_INFO -d DEBUG_INFO_DWARF5 -d DEBUG_INFO_DWARF4 -d DEBUG_INFO_DWARF_TOOLCHAIN_DEFAULT -e DEBUG_INFO_NONE -d DEBUG_INFO_BTF
$S --set-str LOCALVERSION "-gemstone" -d LOCALVERSION_AUTO
make -s O="$O" ARCH=arm64 CROSS_COMPILE="$CC" olddefconfig

# --- 3) build the .deb -----------------------------------------------------------------------------
echo "### build start $(date)"
# DPKG_FLAGS=-d: dpkg-checkbuilddeps wants arm64 build-deps (libssl-dev:arm64) in a cross build; host tools are enough
# linux-headers would need arm64 OpenSSL to cross-build its host tools; not needed to boot -> skip it
make O="$O" ARCH=arm64 CROSS_COMPILE="$CC" -j"$(nproc)" KDEB_PKGVERSION=$PKGVER DPKG_FLAGS=-d \
     DEB_BUILD_PROFILES="pkg.linux-upstream.nokernelheaders pkg.linux-upstream.nokerneldbg" bindeb-pkg > "$K/make.log" 2>&1 \
  || { grep -E 'error|Error' "$K/make.log" | tail -30; exit 1; }
rm -f "$OUTD"/linux-*.deb
mv -f "$K"/linux-*.deb "$OUTD/" 2>/dev/null || mv -f "$O"/../linux-*.deb "$OUTD/" 2>/dev/null || true
cp "$O/arch/arm64/boot/Image" "$OUTD/"
build_dtb
cat "$O/include/config/kernel.release" > "$OUTD/release"
ls -la "$OUTD"
echo "### build end $(date)"
echo DEBIAN_KERNEL_OK
