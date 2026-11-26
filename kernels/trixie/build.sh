#!/bin/bash
# Debian trixie kernel (6.12, the kernel Pardus 25 itself uses) for the T3 Gemstone O1.
#
#   Debian's own kernel source (linux 6.12.y from trixie / trixie-security), with Debian's patches
#   + Debian's own arm64 config, plus the few TI/board options Debian leaves off
#   + (VARIANT=hdmi) kernels/trixie-hdmi/patches: the display (tidss) and GPU (imagination) drivers
#     brought back from 6.18, then the HDMI series
#   + the board description from board/dts/, compiled next to the tree
#   -> kernels/trixie{,-hdmi}/out/: linux-image-<ver>-gemstone-trixie{,-hdmi}+_..._arm64.deb, Image, DTB
#
# Usage:  kernels/trixie/build.sh             headless (no patches)   ~60-90 min on 4 vCPU
#         kernels/trixie-hdmi/build.sh        desktop (HDMI + GPU)
#         PREP_ONLY=1 / DTB_ONLY=1 as in kernels/debian/build.sh
# Versions: versions.env (TRIXIE_KERNEL_*)
set -euo pipefail
TOP=${TOP:-$(cd "$(dirname "$0")/../.." && pwd)}
. "$TOP/versions.env"
VARIANT=${VARIANT:-plain}
case "$VARIANT" in
  plain) K=${K:-$TOP/kernels/trixie};      DTSNAME=k3-am67a-t3-gem-o1-headless.dts; LV=-gemstone-trixie ;;
  hdmi)  K=${K:-$TOP/kernels/trixie-hdmi}; DTSNAME=k3-am67a-t3-gem-o1-lts-hdmi.dts;  LV=-gemstone-trixie-hdmi
         PATCHES=$K/patches ;;
  *) echo "VARIANT must be plain or hdmi"; exit 1 ;;
esac
DL=$TOP/kernels/trixie          # downloads are shared by both variants
SRC=$K/src; O=$K/build; OUTD=$K/out
CC=${CC:-$TOP/gcc-$GCC_VERSION-nolibc/aarch64-linux/bin/aarch64-linux-}
DEBVER=$TRIXIE_KERNEL_DEBVER
ABI=$TRIXIE_KERNEL_ABI
PKGVER=$TRIXIE_KERNEL_PKGVER
POOLS="https://security.debian.org/debian-security/pool/updates/main/l/linux https://deb.debian.org/debian/pool/main/l/linux"
SNAPSHOT=${SNAPSHOT:-https://snapshot.debian.org/file}
mkdir -p "$K" "$DL" "$O" "$OUTD"

build_dtb() {
  local dtc=dtc; [ -x "$O/scripts/dtc/dtc" ] && dtc=$O/scripts/dtc/dtc
  "$TOP/board/dts/build-dtb.sh" "$SRC" "$DTSNAME" "$OUTD/k3-am67a-t3-gem-o1.dtb" "$dtc"
}
if [ "${DTB_ONLY:-0}" = 1 ]; then
  [ -d "$SRC/.git" ] || { echo "no kernel source yet: run $K/build.sh once"; exit 1; }
  build_dtb; echo DTB_OK; exit 0
fi

# Pinned Debian files (versions.env): name, sha1 (snapshot.debian.org address), sha256 (checked).
# A security upload lives on security.debian.org, later also in the main pool; old versions stay on
# snapshot.debian.org by their sha1.
fetch() {
  local f=$1 sha1 sha256 p
  read -r _ sha1 sha256 <<<"$(echo "$TRIXIE_KERNEL_PINNED" | awk -v f="$f" '$1==f')"
  [ -n "$sha256" ] || { echo "not pinned: $f"; exit 1; }
  ok() { [ -s "$DL/$f" ] && echo "$sha256  $DL/$f" | sha256sum -c --quiet - >/dev/null 2>&1; }
  ok && return
  for p in $POOLS; do wget -q "$p/$f" -O "$DL/$f" || true; ok && return; done
  echo "$f: not in the Debian pools any more, using snapshot.debian.org"
  wget -q "$SNAPSHOT/$sha1" -O "$DL/$f"
  ok || { echo "checksum mismatch: $f"; exit 1; }
}

# --- 1) source: Debian's package source (Debian's patches applied) as a git tree -----------------
STAMP=$SRC/.prepared-$DEBVER
[ "$VARIANT" = hdmi ] && STAMP=$STAMP-$(cat "$PATCHES"/0*.patch | sha256sum | cut -c1-12)
if [ ! -f "$STAMP" ]; then
  for f in "linux_${DEBVER}.dsc" "linux_${DEBVER%%-*}.orig.tar.xz" "linux_${DEBVER}.debian.tar.xz"; do fetch "$f"; done
  rm -rf "$SRC"
  dpkg-source -x "$DL/linux_${DEBVER}.dsc" "$SRC" > "$K/dpkg-source.log" 2>&1
  cd "$SRC"
  git init -q; git checkout -q -b gemstone
  git add -A -f; git -c user.name=gemstone -c user.email=gemstone@localhost commit -q -m "Debian linux $DEBVER (debian/patches applied)"
  git tag "debian-$DEBVER"
  if [ "$VARIANT" = hdmi ]; then
    git -c user.name=gemstone -c user.email=gemstone@localhost am -q "$PATCHES"/0*.patch
    echo "source ready: $(git log --oneline "debian-$DEBVER"..HEAD | wc -l) patches on top of Debian $DEBVER"
  fi
  touch "$STAMP"
fi
[ "${PREP_ONLY:-0}" = 1 ] && { echo PREP_OK; exit 0; }

# --- 2) config: Debian's exact config, from its official image package ---------------------------
IMGDEB=linux-image-${ABI}-unsigned_${DEBVER}_arm64.deb
if [ ! -s "$DL/config-debian-$DEBVER" ]; then
  fetch "$IMGDEB"
  CF=$(dpkg-deb -c "$DL/$IMGDEB" | awk '{print $6}' | grep -E '/boot/config-' | head -1)
  dpkg-deb --fsys-tarfile "$DL/$IMGDEB" | tar -xO "$CF" > "$DL/config-debian-$DEBVER"
fi
cp "$DL/config-debian-$DEBVER" "$O/.config"
cd "$SRC"
S="scripts/config --file $O/.config"
WANT=()
want() { local m=$1; shift; for o in "$@"; do $S "$m" "$o"; WANT+=("$o"); done; }
# board: PMIC, humidity sensor
want -e MFD_TPS65219 REGULATOR_TPS65219; want -m HDC2010
# TI K3 core pieces Debian leaves off. Without the interrupt routers GPIO interrupts fail ->
# the SD card's GPIO power switches never come up -> no root file system.
want -e TI_SCI_INTR_IRQCHIP TI_SCI_INTA_IRQCHIP TI_K3_RINGACC TI_K3_PSIL TI_K3_UDMA \
        TI_K3_UDMA_GLUE_LAYER TI_K3_CPPI_DESC_POOL
want -m TI_K3_AM65_CPSW_NUSS TI_DAVINCI_MDIO PHY_TI_GMII_SEL DP83TG720_PHY PHY_CADENCE_SIERRA \
        PHY_AM654_SERDES OMAP_USB2 RTC_DRV_TI_K3 HWSPINLOCK_OMAP RESET_TI_SYSCON \
        TI_K3_DSP_REMOTEPROC INPUT_TPS65219_PWRBUTTON TI_EQEP I2C_CADENCE PHY_CAN_TRANSCEIVER \
        PWM_TIEHRPWM
if [ "$VARIANT" = hdmi ]; then
  want -m DRM_TIDSS DRM_SII902X DRM_DISPLAY_CONNECTOR PHY_CADENCE_DPHY DRM_POWERVR \
          SND_SOC_DAVINCI_MCASP SND_SOC_TI_UDMA_PCM SND_SOC_TI_EDMA_PCM SND_SOC_TI_SDMA_PCM \
          SND_SIMPLE_CARD SND_SOC_HDMI_CODEC
fi
# SA2UL crypto accelerator oopsed in its self-tests on J722S with Debian 7.2 -> off
$S -d CRYPTO_DEV_SA2UL
# Debian's signing key is not ours: sign modules with a key generated at build time
$S -e MODULE_SIG -e MODULE_SIG_ALL -d MODULE_SIG_FORCE --set-str MODULE_SIG_KEY "certs/signing_key.pem" \
   --set-str SYSTEM_TRUSTED_KEYS "" --set-str SYSTEM_REVOCATION_KEYS ""
$S -d DEBUG_INFO -d DEBUG_INFO_DWARF5 -d DEBUG_INFO_DWARF4 -d DEBUG_INFO_DWARF_TOOLCHAIN_DEFAULT -e DEBUG_INFO_NONE -d DEBUG_INFO_BTF
$S --set-str LOCALVERSION "$LV" -d LOCALVERSION_AUTO
make -s O="$O" ARCH=arm64 CROSS_COMPILE="$CC" olddefconfig
for o in "${WANT[@]}"; do grep -qE "^CONFIG_$o=[ym]" "$O/.config" || echo "WARNING: CONFIG_$o did not stay on"; done

# --- 3) build the .deb -----------------------------------------------------------------------------
echo "### build start $(date)"
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
echo "TRIXIE_$(echo "$VARIANT" | tr a-z A-Z)_KERNEL_OK"
