#!/bin/bash
# T3 Gemstone O1 - Pardus 25 (yirmibes) or Debian 13 (trixie) arm64 rootfs + bootable SD image
# Layout: p1 FAT32 "BOOT" (bootloader, kernel, DTB, initramfs, uEnv.txt) + p2 btrfs "rootfs"
# Usually started by ./build.sh (desktop | headless). Directly:
#   sudo ./scripts/03-rootfs-image.sh --distro pardus --flavor lite --kernel debian      (desktop)
#   sudo ./scripts/03-rootfs-image.sh --distro pardus --flavor minimal --kernel mainline (headless)
# Options (command line > environment variable > marker file in the repo folder > default):
#   --distro  pardus | debian               DISTRO           (default debian; ./go-pardus = pardus)
#   --flavor  full | lite | minimal         FLAVOR   .flavor (default lite; old marker .lite = lite)
#   --kernel  lts-hdmi | mainline | stable-hdmi | stable | trixie-hdmi | trixie | debian | t3 | ti   KERNEL .kernel (default lts-hdmi)
#   --vendor-bl / --vendor-initrd           VENDOR_BL / VENDOR_INITRD  .vendor-bl / .vendor-initrd
#   --xz N    xz level of the .img.xz       XZ_LEVEL         (default 3 = fast; 6 for releases)
# sudo drops environment variables: use the command line options (or marker files).
set -euo pipefail
[ "$(id -u)" = 0 ] || { echo "run with sudo"; exit 1; }
TOP=${TOP:-$(cd "$(dirname "$0")/.." && pwd)}
OUT=$TOP/out
while [ $# -gt 0 ]; do
  case "$1" in
    --distro) DISTRO=${2:?}; shift 2 ;;
    --flavor) FLAVOR=${2:?}; shift 2 ;;
    --kernel) KERNEL=${2:?}; shift 2 ;;
    --vendor-bl) VENDOR_BL=1; shift ;;
    --vendor-initrd) VENDOR_INITRD=1; shift ;;
    --xz) XZ_LEVEL=${2:?}; shift 2 ;;
    -h|--help) sed -n '2,/^set -euo/p' "$0" | sed '$d'; exit 0 ;;
    *) echo "unknown option: $1 (see --help)"; exit 1 ;;
  esac
done
XZ_LEVEL=${XZ_LEVEL:-3}
case "$XZ_LEVEL" in [0-9]) ;; *) echo "--xz must be 0-9"; exit 1 ;; esac
DISTRO=${DISTRO:-debian}
case "$DISTRO" in
  debian)
    SUITE=${SUITE:-trixie}                       # name used in image / rootfs dir
    BSUITE=$SUITE                                # suite debootstrap pulls from
    MIRROR=${MIRROR:-http://deb.debian.org/debian}
    ROOTFS=$TOP/build/rootfs-$SUITE
    IMG_SIZE=${IMG_SIZE:-8G}
    USERNAME=${USERNAME:-debian}
    SYSLANG=en_US.UTF-8; XKB=us ;;
  pardus)
    # Pardus 25 = Debian 13 packages mirrored as "yirmibes-deb" + Pardus' own packages in "yirmibes"
    SUITE=${SUITE:-yirmibes}
    BSUITE=$SUITE-deb
    PARDUS=${PARDUS:-http://depo.pardus.org.tr}
    MIRROR=$PARDUS/pardus
    ROOTFS=$TOP/build/rootfs-pardus-$SUITE
    IMG_SIZE=${IMG_SIZE:-12G}
    USERNAME=${USERNAME:-pardus}
    SYSLANG=tr_TR.UTF-8; XKB=tr ;;
  *) echo "DISTRO must be debian or pardus"; exit 1 ;;
esac
# FLAVOR=full (Pardus XFCE desktop with LibreOffice, Firefox …), lite (slim Pardus XFCE, no office
# suite, boot-time timers off) or minimal (no desktop at all: console + SSH, for headless use).
# Each has its own rootfs dir, so all can be kept.
FLAVOR=${FLAVOR:-$(cat "$TOP/.flavor" 2>/dev/null || { [ -f "$TOP/.lite" ] && echo lite; } || echo lite)}
case "$FLAVOR" in full|lite|minimal) ;; *) echo "FLAVOR must be full, lite or minimal"; exit 1 ;; esac
# lite and minimal: no developer tools, docs, man pages or extra languages (step 2c)
SLIM=0; [ "$FLAVOR" = full ] || SLIM=1
# lite (Pardus) package set, installed without recommends. Packages added here later are installed
# into an existing lite rootfs by step 2b, so the list can grow without a full reinstall.
LITE_PKGS="pardus-archive-keyring pardus-locales pardus-xfce-settings pardus-xfce-gtk-theme pardus-xfce-icon-theme
  pardus-backgrounds pardus-wallpaper-25-0 pardus-menus fonts-ubuntu
  desktop-base pardus-lightdm-greeter pardus-lightdm-greeter-settings pardus-xfce-greeter
  adwaita-icon-theme tango-icon-theme gnome-icon-theme
  xserver-xorg-core xserver-xorg-video-fbdev xserver-xorg-input-libinput x11-xserver-utils xinit
  lightdm lightdm-gtk-greeter
  xfwm4 xfce4-panel xfdesktop4 xfce4-session xfce4-settings xfconf thunar xfce4-terminal xfce4-appfinder
  libxfce4ui-utils xfce4-whiskermenu-plugin xfce4-pulseaudio-plugin xfce4-notifyd xfce4-xkb-plugin
  xfce4-power-manager xfce4-power-manager-plugins
  network-manager-gnome dbus-x11 dbus-user-session gvfs polkitd pipewire pipewire-pulse wireplumber
  mesa-utils gstreamer1.0-tools gstreamer1.0-plugins-base gstreamer1.0-plugins-good
  pardus-software pardus-update pardus-mycomputer pardus-about pardus-package-installer pardus-hotspot
  pardus-night-light pardus-usb-formatter pardus-image-writer pardus-font-manager pardus-xfce-tweaks"
if [ "$FLAVOR" = lite ]; then ROOTFS=$ROOTFS-lite; IMG_SIZE=${IMG_SIZE_LITE:-8G}; fi
if [ "$FLAVOR" = minimal ]; then ROOTFS=$ROOTFS-minimal; IMG_SIZE=${IMG_SIZE_MINIMAL:-4G}; fi
# Boot chain. Default: everything ours (bootloader from 01-bootloader.sh, Debian initramfs) = "-own".
# Only for comparison/debugging, T3's own files copied from a working Gemstone SD card into
# $VENDOR_BOOT can be used instead: VENDOR_BL=1 (tiboot3/tispl/u-boot) and/or VENDOR_INITRD=1.
VENDOR_BOOT=${VENDOR_BOOT:-$TOP/vendor-boot}
VENDOR_BL=${VENDOR_BL:-$(if [ -f "$TOP/.vendor-bl" ]; then echo 1; else echo 0; fi)}
VENDOR_INITRD=${VENDOR_INITRD:-$(if [ -f "$TOP/.vendor-initrd" ]; then echo 1; else echo 0; fi)}
if [ "$VENDOR_BL$VENDOR_INITRD" != 00 ] && [ ! -f "$VENDOR_BOOT/tispl.bin" ]; then
  echo "VENDOR_BL/VENDOR_INITRD need T3's boot files in $VENDOR_BOOT"; exit 1
fi
case "$VENDOR_BL$VENDOR_INITRD" in 00) SUFFIX=-own ;; 11) SUFFIX=-vboot ;; 10) SUFFIX=-vbl ;; 01) SUFFIX=-vinitrd ;; esac
# Kernel (README "Çekirdek seçimi", docs/BELGE.md §21, §24):
#   t3       = T3's 6.12 kernel source, 02-kernel.sh          -> out/kernel/*.deb, out/boot/{Image,dtb,overlays}
#   debian   = Debian 7.2 + HDMI patches, kernels/debian      -> kernels/debian/out/{*.deb,Image,dtb,release}
#   mainline = kernel.org 6.18 LTS, no patches, no HDMI       -> kernels/mainline/out/...
#   lts-hdmi = kernel.org 6.18 LTS + HDMI patches              -> kernels/lts-hdmi/out/...
#   stable / stable-hdmi = kernel.org 7.3 stable (+ HDMI)     -> kernels/stable*/out/...
#   trixie / trixie-hdmi = Debian trixie 6.12 (+ HDMI/GPU)    -> kernels/trixie*/out/...
#   ti       = TI's kernel source (not prepared yet)          -> kernels/ti/out/...
KERNEL=${KERNEL:-$(cat "$TOP/.kernel" 2>/dev/null || echo lts-hdmi)}
case "$KERNEL" in
  t3)        KDIR=$OUT/kernel; KBOOT=$OUT/boot ;;
  debian|ti|mainline|lts-hdmi|stable|stable-hdmi|trixie|trixie-hdmi) KDIR=$TOP/kernels/$KERNEL/out; KBOOT=$KDIR ;;
  *) echo "KERNEL must be lts-hdmi, mainline, stable-hdmi, stable, trixie-hdmi, trixie, debian, t3 or ti"; exit 1 ;;
esac
[ "$KERNEL" = t3 ] || SUFFIX=$SUFFIX-k$KERNEL
# exactly one kernel package: the newest one (older builds may still lie next to it)
KDEB=$(ls -t "$KDIR"/linux-image-*.deb 2>/dev/null | head -1)
[ -n "$KDEB" ] || { echo "no linux-image-*.deb in $KDIR (build the kernel first)"; exit 1; }
IMG=$OUT/t3-gem-o1-$DISTRO-$SUITE-arm64-$FLAVOR-$(date +%Y%m%d)$SUFFIX.img
# Ethernet: static address in T3's own U-Boot convention (board 10.42.0.12, host PC 10.42.0.11)
NET_IP=${NET_IP:-10.42.0.12}
NET_PREFIX=${NET_PREFIX:-24}
NET_GW=${NET_GW:-10.42.0.1}
NET_DNS=${NET_DNS:-1.1.1.1;8.8.8.8}
NET_PC=${NET_PC:-10.42.0.11}       # the PC running Wireshark/SSH; boot-stage beacons are ARP'd at it
log(){ echo "### $*"; }

# apt/sqv reject signatures "from the future" if the build host clock is behind.
# Compare with the mirror's HTTP Date header and correct the clock if it is off by > 5 min.
# This changes the HOST clock from an unauthenticated HTTP header: meant for a throw-away build VM
# whose clock drifts. On a real machine use NTP and run with FIX_CLOCK=0.
srv=
[ "${FIX_CLOCK:-1}" = 1 ] && srv=$(wget -qS --spider "$MIRROR/dists/$BSUITE/InRelease" 2>&1 | sed -n 's/^ *Date: //p' | head -1)
if [ -n "$srv" ]; then
  diff=$(( $(date -d "$srv" +%s) - $(date +%s) ))
  if [ "${diff#-}" -gt 300 ]; then
    log "system clock is off by ${diff}s, setting it from $MIRROR ($srv)"
    date -s "$srv" >/dev/null
  fi
fi

# host tools (fail early instead of after a long rootfs build)
need=()
for t in debootstrap:debootstrap qemu-aarch64-static:qemu-user-static mkfs.btrfs:btrfs-progs \
         mkfs.vfat:dosfstools parted:parted rsync:rsync xz:xz-utils; do
  command -v "${t%%:*}" >/dev/null || need+=("${t##*:}")
done
if [ ${#need[@]} -gt 0 ]; then log "installing host tools: ${need[*]}"; apt-get install -y "${need[@]}"; fi

# The build host's debian-archive-keyring may be older and lack trixie signing keys:
# fetch the current keyring package from Debian and use it only for debootstrap.
fetch_keyring(){  # $1 = pool dir URL, $2 = package name, $3 = output .gpg
  [ -s "$3" ] && return 0
  log "fetching current $2"
  local kd deb; kd=$(mktemp -d)
  deb=$(wget -qO- "$1/" | grep -o "$2_[0-9.]*_all\.deb" | sort -V | tail -1)
  [ -n "$deb" ] || { echo "cannot find $2 in $1"; exit 1; }
  wget -q -O "$kd/k.deb" "$1/$deb"
  dpkg-deb -x "$kd/k.deb" "$kd/x"
  mkdir -p "$(dirname "$3")"
  # binary OpenPGP keyrings can simply be concatenated
  cat $(find "$kd/x" -name '*.gpg' | sort) > "$3"
  rm -rf "$kd"
  log "using keyring from $deb"
}
if [ "$DISTRO" = pardus ]; then
  KEYRING=$TOP/build/pardus-archive-keyring.gpg
  fetch_keyring "$MIRROR/pool/main/p/pardus-archive-keyring" pardus-archive-keyring "$KEYRING"
else
  KEYRING=$TOP/build/debian-archive-keyring.gpg
  fetch_keyring "$MIRROR/pool/main/d/debian-archive-keyring" debian-archive-keyring "$KEYRING"
fi

cleanup(){
  set +e
  chroot_down
  mountpoint -q /mnt/gem-root/boot/firmware && umount /mnt/gem-root/boot/firmware
  mountpoint -q /mnt/gem-root && umount /mnt/gem-root
  [ -n "${LOOP:-}" ] && losetup -d "$LOOP"
}
trap cleanup EXIT

# enter / leave the arm64 rootfs: bind mounts, the build host's DNS, qemu for the arm64 programs
chroot_up(){
  for m in dev dev/pts proc sys run; do mountpoint -q "$ROOTFS/$m" || mount --bind "/$m" "$ROOTFS/$m"; done
  # resolv.conf may be a symlink into /run (systemd-resolved): a real file for the build
  rm -f "$ROOTFS/etc/resolv.conf"; cat /etc/resolv.conf > "$ROOTFS/etc/resolv.conf"
  cp /usr/bin/qemu-aarch64-static "$ROOTFS/usr/bin/"
}
chroot_down(){
  for m in dev/pts dev proc sys run; do mountpoint -q "$ROOTFS/$m" && umount -l "$ROOTFS/$m"; done
  return 0
}

# ---------- 1. debootstrap ----------
if [ ! -f "$ROOTFS/.stage1-done" ]; then
  log "debootstrap $DISTRO $BSUITE arm64"
  rm -rf "$ROOTFS"; mkdir -p "$ROOTFS"
  # Pardus suites are not known to debootstrap: use the trixie script (same Debian 13 base)
  debootstrap --arch=arm64 --foreign --keyring="$KEYRING" --include=ca-certificates,locales,systemd-sysv,dbus \
    --components=main,contrib,non-free,non-free-firmware "$BSUITE" "$ROOTFS" "$MIRROR" \
    /usr/share/debootstrap/scripts/trixie
  cp /usr/bin/qemu-aarch64-static "$ROOTFS/usr/bin/"
  chroot "$ROOTFS" /debootstrap/debootstrap --second-stage
  touch "$ROOTFS/.stage1-done"
fi

# wait for 02-kernel.sh (may run in parallel)
until [ -f "$KDIR/release" ]; do log "waiting for kernel build ($KDIR)..."; sleep 30; done
REL=$(cat "$KDIR/release")
# the package must be the build that wrote "release" (else the initramfs is made for other modules)
KPKG=$(dpkg-deb -f "$KDEB" Package)
[ "$KPKG" = "linux-image-$REL" ] || {
  echo "kernel mismatch: $(basename "$KDEB") is $KPKG, but $KDIR/release says $REL (rebuild the kernel)"; exit 1; }

# a previous run may have finished stage 2 and failed later: detect it instead of reinstalling
if [ ! -f "$ROOTFS/.stage2-done" ] && [ -f "$ROOTFS/boot/initrd.img-$REL" ] && \
   [ -d "$ROOTFS/usr/share/xsessions" ] && [ -f "$ROOTFS/etc/systemd/system/regen-ssh-keys.service" ]; then
  log "stage 2 already completed by a previous run"
  touch "$ROOTFS/.stage2-done"
fi

if [ ! -f "$ROOTFS/.stage2-done" ]; then
chroot_up

# ---------- 2. configure + packages ----------
log "configure rootfs"
if [ "$DISTRO" = pardus ]; then
  # same layout as an installed Pardus 25: Pardus packages + Debian base + security
  cat > "$ROOTFS/etc/apt/sources.list" <<EOF
deb $PARDUS/pardus $SUITE main contrib non-free non-free-firmware
deb $PARDUS/pardus $SUITE-deb main contrib non-free non-free-firmware
deb $PARDUS/guvenlik $SUITE-deb main contrib non-free non-free-firmware
EOF
  # key for apt until the pardus-archive-keyring package itself gets installed
  install -m644 "$KEYRING" "$ROOTFS/etc/apt/trusted.gpg.d/pardus-build.gpg"
  # bootloader/splash bits that make no sense on this board (U-Boot + extlinux, serial console)
  mkdir -p "$ROOTFS/etc/apt/preferences.d"
  cat > "$ROOTFS/etc/apt/preferences.d/no-grub-plymouth" <<'EOF'
Package: grub* *-grub-theme plymouth* pardus-installer* os-prober
Pin: release *
Pin-Priority: -1
EOF
  # Pardus ships a newer arch:all xfdesktop4-data (…pardusN) but on arm64 only Debian's
  # xfdesktop4 binary, which needs data (= its own version): keep the matching Debian one.
  cat > "$ROOTFS/etc/apt/preferences.d/arm64-xfdesktop" <<'EOF'
Package: xfdesktop4-data
Pin: release n=yirmibes-deb
Pin-Priority: 1001
EOF
else
  cat > "$ROOTFS/etc/apt/sources.list" <<EOF
deb $MIRROR $SUITE main contrib non-free non-free-firmware
deb $MIRROR $SUITE-updates main contrib non-free non-free-firmware
deb http://security.debian.org/debian-security $SUITE-security main contrib non-free non-free-firmware
EOF
fi
echo gemstone > "$ROOTFS/etc/hostname"
printf '127.0.0.1\tlocalhost\n127.0.1.1\tgemstone\n::1\tlocalhost ip6-localhost ip6-loopback\n' > "$ROOTFS/etc/hosts"
cat > "$ROOTFS/etc/fstab" <<EOF
LABEL=rootfs  /              btrfs  defaults,noatime,compress=zstd  0 0
LABEL=BOOT    /boot/firmware vfat   defaults,noatime                0 2
EOF
mkdir -p "$ROOTFS/boot/firmware"
# initramfs compressed with gzip (kernel + U-Boot friendly), include btrfs + mmc
mkdir -p "$ROOTFS/etc/initramfs-tools/conf.d"
echo COMPRESS=gzip > "$ROOTFS/etc/initramfs-tools/conf.d/compress"
printf 'btrfs\nsdhci_am654\nmmc_block\n' >> "$ROOTFS/etc/initramfs-tools/modules"
# do not let kernel postinst try to touch a bootloader
mkdir -p "$ROOTFS/etc/kernel/postinst.d"

cat > "$ROOTFS/tmp/setup.sh" <<'EOS'
#!/bin/bash
set -e
export DEBIAN_FRONTEND=noninteractive LC_ALL=C
sed -i 's/^# *en_US.UTF-8/en_US.UTF-8/; s/^# *tr_TR.UTF-8/tr_TR.UTF-8/' /etc/locale.gen
locale-gen; update-locale LANG=$SYSLANG
cat > /etc/default/keyboard <<EOF
XKBMODEL="pc105"
XKBLAYOUT="$XKB"
XKBVARIANT=""
XKBOPTIONS=""
BACKSPACE="guess"
EOF
apt-get update
# full-upgrade: Pardus' base-files (os-release = Pardus) pulls in a new package, plain upgrade keeps it back
apt-get -y full-upgrade
# install only packages that exist in this suite; report the rest instead of aborting
inst(){ local ok=() miss=(); for p in "$@"; do
          if apt-cache show "$p" >/dev/null 2>&1; then ok+=("$p"); else miss+=("$p"); fi; done
        [ ${#miss[@]} -eq 0 ] || echo "### WARNING: not available in this suite, skipped: ${miss[*]}"
        # apt 3's new solver gives up on some mixed-repo cases the classic one can solve
        apt-get install -y $APT_OPTS "${ok[@]}" || \
          { echo "### retrying with the classic apt solver"; apt-get install -y --solver internal $APT_OPTS "${ok[@]}"; }; }
# base / system
APT_OPTS=--no-install-recommends inst \
  initramfs-tools btrfs-progs dosfstools e2fsprogs parted u-boot-tools device-tree-compiler \
  sudo openssh-server network-manager wpasupplicant iw wireless-regdb bluez rfkill \
  systemd-timesyncd systemd-resolved udev kmod console-setup keyboard-configuration \
  bash-completion less nano curl wget htop tmux rsync unzip xz-utils zstd \
  i2c-tools spi-tools gpiod can-utils ethtool usbutils pciutils net-tools iproute2 iputils-ping \
  alsa-utils v4l-utils python3 python3-libgpiod python3-smbus2 \
  firmware-realtek firmware-misc-nonfree firmware-linux-free
# developer tools (compilers, git, vim, pip, man pages): only in "full"; lite/minimal drop them (step 2c)
[ "$FLAVOR" = full ] && APT_OPTS=--no-install-recommends inst build-essential cmake git vim python3-pip python3-venv pkg-config man-db
if [ "$FLAVOR" = minimal ]; then
  # "minimal" = no desktop: console, SSH, network, board tools only (no X, no audio stack)
  [ "$DISTRO" = pardus ] && APT_OPTS=--no-install-recommends inst pardus-archive-keyring pardus-locales
  rm -f /etc/apt/trusted.gpg.d/pardus-build.gpg
  systemctl mask apt-daily.timer apt-daily-upgrade.timer man-db.timer e2scrub_all.timer \
    NetworkManager-wait-online.service 2>/dev/null || true
elif [ "$FLAVOR" = lite ] && [ "$DISTRO" = pardus ]; then
  # "lite" = minimal Pardus XFCE: the same Pardus XFCE look and panel (pardus-xfce-settings, Pardus
  # theme/icons/wallpapers via desktop-base, Pardus' own login screen) and the Pardus GTK tools, but
  # package by package and without recommends. Not installed (pardus-xfce-desktop pulls these in):
  # xfce4-goodies, printing (cups, system-config-printer), gnome-system-tools, LibreOffice, Firefox,
  # GIMP, VLC, Evolution, plymouth, light-locker. Panel plugins are exactly the ones Pardus' panel uses.
  APT_OPTS=--no-install-recommends inst $LITE_PKGS
  rm -f /etc/apt/trusted.gpg.d/pardus-build.gpg
  # speed: no compositor (software rendering, no GPU driver yet), no tips window at login
  rm -f /etc/xdg/pardus/autostart/xfce4-tips-autostart.desktop /etc/xdg/autostart/xfce4-tips-autostart.desktop
  for f in /etc/xdg/pardus/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml; do
    [ -f "$f" ] && sed -i 's/\(name="use_compositing" type="bool" value="\)true/\1false/' "$f"
  done
  # boot speed: periodic maintenance timers and "wait for network" are not needed on the board
  systemctl mask apt-daily.timer apt-daily-upgrade.timer man-db.timer e2scrub_all.timer \
    NetworkManager-wait-online.service 2>/dev/null || true
elif [ "$DISTRO" = pardus ]; then
  # "full": Pardus XFCE desktop (with recommends: LibreOffice, Pardus tools, TR language packs).
  # PipeWire comes with pardus-common-desktop; grub/plymouth are pinned away.
  APT_OPTS= inst pardus-archive-keyring pardus-xfce-desktop pardus-locales firefox-esr-l10n-tr \
    xserver-xorg-video-fbdev mesa-utils pavucontrol gstreamer1.0-tools gstreamer1.0-plugins-good gstreamer1.0-plugins-bad
  rm -f /etc/apt/trusted.gpg.d/pardus-build.gpg   # the package's own keyring takes over
else
  # "full": XFCE desktop like BeagleY-AI xfce image
  APT_OPTS= inst task-xfce-desktop lightdm xserver-xorg-video-fbdev mesa-utils \
    firefox-esr pulseaudio pavucontrol gstreamer1.0-tools gstreamer1.0-plugins-good gstreamer1.0-plugins-bad
fi
# kernel from our build
dpkg -i /tmp/kernel/linux-image-*.deb
ls /tmp/kernel/linux-libc-dev_*.deb >/dev/null 2>&1 && dpkg -i /tmp/kernel/linux-libc-dev_*.deb || true
# user (BeagleBoard convention <user>/temppwd, password must be changed on first login)
U=$USERNAME
# render: GPU (/dev/dri/renderD128) also outside the desktop session, e.g. over SSH
id -u $U >/dev/null 2>&1 || useradd -m -s /bin/bash -G sudo,adm,dialout,audio,video,render,plugdev,netdev,i2c,gpio,bluetooth $U 2>/dev/null || \
  useradd -m -s /bin/bash -G sudo,adm,dialout,audio,video,render,plugdev $U
echo "$U:temppwd" | chpasswd
chage -d 0 $U
systemctl enable ssh NetworkManager systemd-timesyncd serial-getty@ttyS2.service
if [ "$FLAVOR" = minimal ]; then systemctl set-default multi-user.target; else systemctl set-default graphical.target || true; fi
apt-get clean
rm -rf /var/lib/apt/lists/*
EOS
chmod +x "$ROOTFS/tmp/setup.sh"
rm -rf "$ROOTFS/tmp/kernel"; mkdir -p "$ROOTFS/tmp/kernel"
cp "$KDEB" "$ROOTFS/tmp/kernel/"
# kernel headers for user space: only useful with a compiler, i.e. in "full"
if [ "$FLAVOR" = full ]; then cp "$KDIR"/linux-libc-dev_*.deb "$ROOTFS/tmp/kernel/" 2>/dev/null || true; fi
chroot "$ROOTFS" env DISTRO="$DISTRO" FLAVOR="$FLAVOR" LITE_PKGS="$LITE_PKGS" USERNAME="$USERNAME" SYSLANG="$SYSLANG" XKB="$XKB" /tmp/setup.sh
chroot "$ROOTFS" update-initramfs -c -k "$REL" || chroot "$ROOTFS" update-initramfs -u -k "$REL"
rm -rf "$ROOTFS/tmp/kernel" "$ROOTFS/tmp/setup.sh"
rm -f "$ROOTFS/etc/ssh/ssh_host_"*   # regenerated on first boot
cat > "$ROOTFS/etc/systemd/system/regen-ssh-keys.service" <<'EOF'
[Unit]
Description=Regenerate SSH host keys
Before=ssh.service
ConditionPathExistsGlob=!/etc/ssh/ssh_host_*_key
[Service]
Type=oneshot
ExecStart=/usr/bin/ssh-keygen -A
[Install]
WantedBy=multi-user.target
EOF
ln -sf /etc/systemd/system/regen-ssh-keys.service "$ROOTFS/etc/systemd/system/multi-user.target.wants/regen-ssh-keys.service"
chroot_down
sha256sum "$KDEB" | cut -d' ' -f1 > "$ROOTFS/.kernel-deb"
touch "$ROOTFS/.stage2-done"
fi

# a Pardus rootfs from an older version of this script still says "Debian" (base-files kept back): fix in place
if [ "$DISTRO" = pardus ] && ! grep -q -i pardus "$ROOTFS/etc/os-release"; then
  log "installing Pardus base-files (os-release)"
  chroot_up
  chroot "$ROOTFS" env DEBIAN_FRONTEND=noninteractive LC_ALL=C sh -c \
    'apt-get update && apt-get -y full-upgrade && apt-get clean && rm -rf /var/lib/apt/lists/*'
  chroot_down
  grep -q -i pardus "$ROOTFS/etc/os-release" || { echo "os-release still not Pardus"; exit 1; }
fi

# ---------- 2b. updates on an existing rootfs (no full stage-2 rerun needed) ----------
# - a rebuilt kernel (02-kernel.sh) is installed when its .deb differs from the one recorded
# - EXTRA_PKGS="pkg1 pkg2" installs additional packages
KSUM=$(sha256sum "$KDEB" | cut -d' ' -f1)
# lite: packages in LITE_PKGS that are not installed yet (the list grew since the rootfs was made)
if [ "$FLAVOR" = lite ] && [ "$DISTRO" = pardus ]; then
  for p in $LITE_PKGS; do
    dpkg-query --admindir="$ROOTFS/var/lib/dpkg" -W -f='${Status}' "$p" 2>/dev/null | grep -q 'ok installed' || \
      EXTRA_PKGS="${EXTRA_PKGS:-} $p"
  done
  [ -n "${EXTRA_PKGS:-}" ] && APT_EXTRA_OPTS=--no-install-recommends
fi
if [ "$(cat "$ROOTFS/.kernel-deb" 2>/dev/null)" != "$KSUM" ] || [ -n "${EXTRA_PKGS:-}" ]; then
  chroot_up
  if [ "$(cat "$ROOTFS/.kernel-deb" 2>/dev/null)" != "$KSUM" ]; then
    log "installing kernel $(basename "$KDEB") into the rootfs"
    mkdir -p "$ROOTFS/tmp/kernel"; cp "$KDEB" "$ROOTFS/tmp/kernel/"
    chroot "$ROOTFS" sh -c 'dpkg -i /tmp/kernel/linux-image-*.deb'
    chroot "$ROOTFS" update-initramfs -c -k "$REL" 2>/dev/null || chroot "$ROOTFS" update-initramfs -u -k "$REL"
    rm -rf "$ROOTFS/tmp/kernel"
    echo "$KSUM" > "$ROOTFS/.kernel-deb"
  fi
  if [ -n "${EXTRA_PKGS:-}" ]; then
    log "installing extra packages: $EXTRA_PKGS"
    chroot "$ROOTFS" env DEBIAN_FRONTEND=noninteractive LC_ALL=C sh -c \
      "apt-get update && apt-get install -y ${APT_EXTRA_OPTS:-} $EXTRA_PKGS && apt-get clean && rm -rf /var/lib/apt/lists/*"
  fi
  chroot_down
fi

# ---------- 2c. firmware, GPU userspace and slimming; each step runs once per rootfs (marker files) ----------
# GPU (PowerVR BXS-4-64): kernel driver drm/imagination (Debian and mainline kernels, docs/BELGE.md §23) needs
#  - firmware powervr/rogue_36.53.104.796_v1.fw: not in Debian 13's firmware packages -> from ti-linux-firmware
#  - Mesa >= 26 for the PowerVR Vulkan driver: Debian 13 has 25.0 -> Mesa from trixie-backports (only Mesa;
#    not in "minimal", which has no graphics stack)
# C7x DSPs: TI's IPC test firmware (all flavours)
# all flavours: only one kernel in the rootfs
# lite + minimal: no compilers/dev tools, no docs/man pages, only tr+en translations
GPU_FW=$TOP/ti-linux-firmware/powervr/rogue_36.53.104.796_v1.fw
DEBKEY=$TOP/build/debian-archive-keyring.gpg
[ "$DISTRO" = pardus ] && fetch_keyring "https://deb.debian.org/debian/pool/main/d/debian-archive-keyring" debian-archive-keyring "$DEBKEY"
DEV_PKGS="build-essential cmake git vim python3-pip python3-venv pkg-config man-db"
# the compiler toolchain itself: removing build-essential does not remove it when dpkg-dev or gcc
# were marked as installed by hand (found in the lite rootfs on 22 Nov: gcc-14, binutils, make ...)
TOOLCHAIN_PKGS="dpkg-dev gcc g++ cpp make binutils libc6-dev linux-libc-dev"
# firmware this board's devices actually load; everything else in the firmware packages is for
# hardware the board does not have (other Wi-Fi chips, NICs, TV tuners, amplifiers ...)
#   rtw88/rtw8822c*     Wi-Fi (RTL8822CS)          rtl_bt/rtl8822cs_*  Bluetooth (same chip)
#   cnm/                video codec (Wave5 VPU)    regulatory.db*      Wi-Fi regulatory database
#   powervr/rogue_36.53.104.796_v1.fw  GPU         ti-ipc/, j722s-c71_*-fw  C7x DSPs (installed by us)
FW_KEEP='^(rtw88/rtw8822c_(wow_)?fw\.bin|rtl_bt/rtl8822cs_(fw|config)\.bin|cnm/.*|regulatory\.db.*|powervr/rogue_36\.53\.104\.796_v1\.fw|ti-ipc/.*|j722s-c71_[01]-fw)$'
need2c=
[ -f "$ROOTFS/.gpu-1" ] || need2c=1
[ "$SLIM" = 1 ] && [ ! -f "$ROOTFS/.slim-1" ] && need2c=1
[ "$SLIM" = 1 ] && [ ! -f "$ROOTFS/.slim-2" ] && need2c=1
ls -d "$ROOTFS"/usr/lib/modules/* | grep -qv "/$REL\$" && need2c=1
if [ -n "$need2c" ]; then
  chroot_up
  ch(){ chroot "$ROOTFS" env DEBIAN_FRONTEND=noninteractive LC_ALL=C sh -c "$*"; }
  # one kernel only: packages of other kernel releases (e.g. T3's after switching to Debian's)
  OTHER=$(chroot "$ROOTFS" dpkg-query -W -f='${Package}\n' 'linux-image-*' 2>/dev/null | grep -v "^linux-image-$REL\$" || true)
  if [ -n "$OTHER" ]; then log "removing other kernels: $OTHER"; ch "dpkg --purge $OTHER"; fi
  for d in "$ROOTFS"/usr/lib/modules/*; do [ "$(basename "$d")" = "$REL" ] || rm -rf "$d"; done
  if [ ! -f "$ROOTFS/.gpu-1" ]; then
    log "GPU: PowerVR firmware + Mesa from trixie-backports; C7x DSP firmware"
    mkdir -p "$ROOTFS/usr/lib/firmware/powervr"; install -m644 "$GPU_FW" "$ROOTFS/usr/lib/firmware/powervr/"
    # C7x DSPs: TI's IPC echo-test firmware, linked under the names the kernel asks for (same as TI's
    # SDK). Without it the kernel logs "j722s-c71_0-fw failed"; real AI firmware replaces the links later.
    mkdir -p "$ROOTFS/usr/lib/firmware/ti-ipc/j722s"
    install -m644 "$TOP"/ti-linux-firmware/ti-ipc/j722s/ipc_echo_test_c7x_*_release_strip.xe71 "$ROOTFS/usr/lib/firmware/ti-ipc/j722s/"
    ln -sf ti-ipc/j722s/ipc_echo_test_c7x_1_release_strip.xe71 "$ROOTFS/usr/lib/firmware/j722s-c71_0-fw"
    ln -sf ti-ipc/j722s/ipc_echo_test_c7x_2_release_strip.xe71 "$ROOTFS/usr/lib/firmware/j722s-c71_1-fw"
  fi
  # Mesa 26 (Vulkan for the GPU) only with a desktop; "minimal" has no graphics stack at all
  if [ ! -f "$ROOTFS/.gpu-1" ] && [ "$FLAVOR" != minimal ]; then
    # With Mesa 26 Xorg's modesetting driver starts glamor on zink-over-PowerVR (experimental here):
    # the desktop gets slow and draws wrongly. Keep the desktop on the CPU path (as before); the GPU
    # stays available to Vulkan applications.
    mkdir -p "$ROOTFS/etc/X11/xorg.conf.d"
    printf 'Section "Device"\n  Identifier "tidss"\n  Driver "modesetting"\n  Option "AccelMethod" "none"\nEndSection\n' \
      > "$ROOTFS/etc/X11/xorg.conf.d/20-gemstone-noglamor.conf"
    if [ "$DISTRO" = pardus ]; then
      install -m644 "$DEBKEY" "$ROOTFS/usr/share/keyrings/gemstone-debian-archive.gpg"
      echo "deb [signed-by=/usr/share/keyrings/gemstone-debian-archive.gpg] https://deb.debian.org/debian trixie-backports main" \
        > "$ROOTFS/etc/apt/sources.list.d/debian-backports.list"
    else
      echo "deb $MIRROR trixie-backports main" > "$ROOTFS/etc/apt/sources.list.d/debian-backports.list"
    fi
    # backports are never chosen on their own (priority 100); packages installed from there with -t
    # (Mesa and what it needs) keep getting their updates from there
    cat > "$ROOTFS/etc/apt/preferences.d/debian-backports" <<'EOF'
Package: *
Pin: release a=trixie-backports
Pin-Priority: 100
EOF
    ch "apt-get update && apt-get install -y --no-install-recommends -t trixie-backports \
        libgl1-mesa-dri libegl-mesa0 libglx-mesa0 libgbm1 mesa-vulkan-drivers mesa-libgallium \
        vulkan-tools mesa-utils && apt-get clean && rm -rf /var/lib/apt/lists/*"
  fi
  touch "$ROOTFS/.gpu-1"
  if [ "$SLIM" = 1 ] && [ ! -f "$ROOTFS/.slim-1" ]; then
    log "$FLAVOR: removing developer tools, documentation and other languages"
    # dpkg keeps them out from now on (also for later apt upgrades on the board); licences stay
    cat > "$ROOTFS/etc/dpkg/dpkg.cfg.d/01-gemstone-lite" <<'EOF'
path-exclude=/usr/share/doc/*
path-include=/usr/share/doc/*/copyright
path-exclude=/usr/share/man/*
path-exclude=/usr/share/info/*
path-exclude=/usr/share/help/*
path-exclude=/usr/share/lintian/*
path-exclude=/usr/share/locale/*
path-include=/usr/share/locale/tr/*
path-include=/usr/share/locale/en/*
path-include=/usr/share/locale/en_GB/*
path-include=/usr/share/locale/locale.alias
EOF
    # dpkg-query fails for a package that was never installed (always so in "minimal"): with pipefail
    # that must not stop the script, so each query ends in "|| true"
    DEV_IN=$(for p in $DEV_PKGS; do { chroot "$ROOTFS" dpkg-query -W -f='${Status} ${Package}\n' "$p" 2>/dev/null || true; } | awk '/ok installed/ {print $4}'; done | xargs)
    if [ -n "$DEV_IN" ]; then ch "apt-get purge -y $DEV_IN"; fi
    ch "apt-get autoremove --purge -y && apt-get clean"
    find "$ROOTFS/usr/share/doc" -mindepth 1 ! -name copyright ! -type d -delete 2>/dev/null || true
    find "$ROOTFS/usr/share/doc" -mindepth 1 -type d -empty -delete 2>/dev/null || true
    rm -rf "$ROOTFS"/usr/share/man/* "$ROOTFS"/usr/share/info/* "$ROOTFS"/usr/share/help/* "$ROOTFS"/usr/share/lintian/*
    find "$ROOTFS/usr/share/locale" -mindepth 1 -maxdepth 1 -type d ! -name tr ! -name en ! -name en_GB -exec rm -rf {} + 2>/dev/null || true
    touch "$ROOTFS/.slim-1"
  fi
  if [ "$SLIM" = 1 ] && [ ! -f "$ROOTFS/.slim-2" ]; then
    log "$FLAVOR: removing the compiler toolchain and firmware for hardware this board does not have"
    TC_IN=$(for p in $TOOLCHAIN_PKGS; do { chroot "$ROOTFS" dpkg-query -W -f='${Status} ${Package}\n' "$p" 2>/dev/null || true; } | awk '/ok installed/ {print $4}'; done | xargs)
    # Only purge a package if that takes nothing else with it. apt removes whatever depends on a
    # purged package: on 22 Nov purging cpp took x11-xserver-utils (xrdb needs cpp), xfce4-session
    # and pardus-xfce-settings with it, and the login screen failed ("xset" not found).
    TC_OK=
    for p in $TC_IN; do
      extra=$(chroot "$ROOTFS" env LC_ALL=C apt-get -s purge "$p" 2>/dev/null | awk '/^Purg /{print $2}' \
              | grep -Ev '^(gcc|g\+\+|cpp|binutils|make|dpkg-dev|libdpkg-perl|lib[a-z0-9+.-]*-dev|libc-dev-bin|linux-libc-dev)([-:]|$)' || true)
      if [ -n "$extra" ]; then log "keeping $p: removing it would also remove $(echo $extra | xargs)"
      else TC_OK="$TC_OK $p"; fi
    done
    if [ -n "$TC_OK" ]; then ch "apt-get purge -y $TC_OK"; fi
    ch "apt-get autoremove --purge -y && apt-get clean"
    # dpkg keeps the other firmware files out on later package upgrades too
    {
      echo 'path-exclude=/usr/lib/firmware/*'
      echo 'path-exclude=/lib/firmware/*'
      for d in /usr/lib/firmware /lib/firmware; do
        for f in rtw88/rtw8822c_fw.bin rtw88/rtw8822c_wow_fw.bin rtl_bt/rtl8822cs_fw.bin rtl_bt/rtl8822cs_config.bin 'cnm/*' 'regulatory.db*'; do
          echo "path-include=$d/$f"
        done
      done
    } > "$ROOTFS/etc/dpkg/dpkg.cfg.d/02-gemstone-firmware"
    FWD=$ROOTFS/usr/lib/firmware
    n0=$(find "$FWD" \( -type f -o -type l \) | wc -l)
    find "$FWD" \( -type f -o -type l \) -printf '%P\n' | { grep -Ev "$FW_KEEP" || true; } | while read -r f; do rm -f "$FWD/$f"; done
    find "$FWD" -mindepth 1 -type d -empty -delete
    log "firmware: $(find "$FWD" \( -type f -o -type l \) | wc -l) of $n0 files kept: $(find "$FWD" \( -type f -o -type l \) -printf '%P ' )"
    # the initramfs may carry copies of removed firmware: make it again
    ch "update-initramfs -u -k $REL"
    touch "$ROOTFS/.slim-2"
  fi
  chroot_down
fi
rm -f "$ROOTFS/usr/bin/qemu-aarch64-static"

# ---------- network: static IP + "alive" beacon (no serial console needed) ----------
log "network: static $NET_IP/$NET_PREFIX, beacon to $NET_PC"
rm -f "$ROOTFS"/etc/NetworkManager/system-connections/*.nmconnection
mkdir -p "$ROOTFS/etc/NetworkManager/system-connections"
# no interface-name: CPSW port may be called eth0 or end0 (systemd naming)
cat > "$ROOTFS/etc/NetworkManager/system-connections/wired-static.nmconnection" <<EOF
[connection]
id=wired-static
type=ethernet
autoconnect=true
autoconnect-priority=100

[ethernet]

[ipv4]
method=manual
address1=$NET_IP/$NET_PREFIX,$NET_GW
dns=$NET_DNS;
may-fail=false

[ipv6]
method=link-local
EOF
chmod 600 "$ROOTFS/etc/NetworkManager/system-connections/wired-static.nmconnection"
# "I am alive" for Wireshark: an ARP/ICMP to the PC every 5 s once Linux userspace is up
cat > "$ROOTFS/etc/systemd/system/gemstone-beacon.service" <<EOF
[Unit]
Description=Ethernet alive beacon to $NET_PC (disable: systemctl disable --now gemstone-beacon)
After=NetworkManager.service
[Service]
ExecStart=/bin/sh -c 'while :; do ping -c1 -W1 $NET_PC >/dev/null 2>&1; sleep 5; done'
Restart=always
[Install]
WantedBy=multi-user.target
EOF
ln -sf /etc/systemd/system/gemstone-beacon.service "$ROOTFS/etc/systemd/system/multi-user.target.wants/gemstone-beacon.service"

# ---------- first boot: grow the root partition + btrfs to the whole card ----------
# T3's initramfs does this itself (firstboot=1); our Debian initramfs does not, so a oneshot
# service does it from the running system. Safe with either initramfs: if the partition is
# already full size, sfdisk/btrfs change nothing. Runs once (marker in /var/lib/gemstone).
log "first-boot root growth service"
mkdir -p "$ROOTFS/usr/local/sbin"
cat >"$ROOTFS/usr/local/sbin/gemstone-growroot" <<'EOF'
#!/bin/sh
# Grow the partition holding / to the end of its disk, then grow the btrfs on it.
set -e
SRC=$(findmnt -no SOURCE / | sed 's/\[.*//')          # e.g. /dev/mmcblk1p2
PART=$(basename "$SRC")
DISK=/dev/$(lsblk -no PKNAME "$SRC")                  # e.g. /dev/mmcblk1
NUM=$(cat /sys/class/block/"$PART"/partition)          # e.g. 2
echo "growroot: $SRC (partition $NUM of $DISK)"
# ", +" = keep the start, use all free space after it. The disk is in use, so do not
# re-read the whole table; partx tells the kernel about the new size of this one partition.
echo ", +" | sfdisk --no-reread --no-tell-kernel -N "$NUM" "$DISK"
partx -u -n "$NUM" "$DISK"
btrfs filesystem resize max /
mkdir -p /var/lib/gemstone && touch /var/lib/gemstone/growroot.done
echo "growroot: done"; df -h /
EOF
chmod 755 "$ROOTFS/usr/local/sbin/gemstone-growroot"
cat > "$ROOTFS/etc/systemd/system/gemstone-growroot.service" <<'EOF'
[Unit]
Description=Grow root partition and btrfs to the whole SD card (first boot only)
ConditionPathExists=!/var/lib/gemstone/growroot.done
After=local-fs.target
[Service]
Type=oneshot
ExecStart=/usr/local/sbin/gemstone-growroot
[Install]
WantedBy=multi-user.target
EOF
ln -sf /etc/systemd/system/gemstone-growroot.service "$ROOTFS/etc/systemd/system/multi-user.target.wants/gemstone-growroot.service"
rm -f "$ROOTFS/var/lib/gemstone/growroot.done"

# ---------- kernel update over SSH: the board-side script (docs/BELGE.md §22) ----------
# Only the script (root:root 755). The passwordless sudo rule that scripts/05-kernel-deploy.sh uses
# is deliberately NOT put into the image: it is equivalent to root for the pardus user (§22.8) and
# is added by hand on development boards only.
install -o root -g root -m 755 "$TOP/board/gemstone-kernel-update" "$ROOTFS/usr/local/sbin/gemstone-kernel-update"

# leftovers of earlier (or interrupted) runs, e.g. mkinitramfs temp files in /var/tmp
rm -rf "${ROOTFS:?}"/tmp/* "${ROOTFS:?}"/var/tmp/*

# on the board, systemd-resolved manages DNS
rm -f "$ROOTFS/etc/resolv.conf"
ln -s ../run/systemd/resolve/stub-resolv.conf "$ROOTFS/etc/resolv.conf"

# ---------- 3. boot partition content ----------
# T3's U-Boot env (u-boot/board/t3/t3-gem-o1/t3-gem-o1.env): bootcmd -> distro_bootcmd -> envboot
# imports BOOT/uEnv.txt (and then clears uenvcmd, so that cannot be used) -> bootcmd_mmc
# = "run args_mmc; run boot_mmc". uEnv.txt redefines exactly those two. boot_mmc loads Image, the DTB
# and the initramfs under the fixed name gemstone-image-rd-t3-gem-o1.cpio.gz (get_initrd_mmc).
# Beacons for Wireshark (no serial console): ARP "who has $NET_PC" = U-Boot read uEnv.txt,
# "who has ${NET_PC%.*}.99" = booti failed.
log "boot files"
BOOTDIR=$TOP/build/bootfs; rm -rf "$BOOTDIR"; mkdir -p "$BOOTDIR/overlays"
if [ "$VENDOR_BL" = 1 ]; then
  log "bootloader: T3's files from $VENDOR_BOOT"
  cp "$VENDOR_BOOT"/tiboot3.bin "$VENDOR_BOOT"/tispl.bin "$VENDOR_BOOT"/u-boot.img "$BOOTDIR/"
else
  log "bootloader: ours ($OUT/boot, 01-bootloader.sh)"
  cp "$OUT"/boot/tiboot3.bin "$OUT"/boot/tispl.bin "$OUT"/boot/u-boot.img "$BOOTDIR/"
fi
log "kernel: $KERNEL ($REL)"
cp "$KBOOT"/Image "$KBOOT"/k3-am67a-t3-gem-o1.dtb "$BOOTDIR/"
if ls "$KBOOT"/overlays/*.dtbo >/dev/null 2>&1; then cp "$KBOOT"/overlays/*.dtbo "$BOOTDIR/overlays/"; else rmdir "$BOOTDIR/overlays"; fi
if [ "$VENDOR_INITRD" = 1 ]; then
  # T3's BusyBox initramfs: grows p2 + btrfs on first boot (firstboot=1), then switch_root
  log "initramfs: T3's from $VENDOR_BOOT"
  cp "$VENDOR_BOOT"/gemstone-image-rd-t3-gem-o1.cpio.gz "$BOOTDIR/"
else
  # our Debian initramfs-tools initrd, under the file name T3's U-Boot env loads;
  # first-boot growth is done by gemstone-growroot.service
  log "initramfs: ours (initramfs-tools, $REL)"
  cp "$ROOTFS/boot/initrd.img-$REL" "$BOOTDIR/gemstone-image-rd-t3-gem-o1.cpio.gz"
fi
# lite: no kernel messages on the HDMI console (printing them slows the boot); for debugging
# delete " quiet loglevel=3" from optargs in BOOT/uEnv.txt (Notepad on Windows is enough)
[ "$SLIM" = 1 ] && QUIET=" quiet loglevel=3" || QUIET=
cat > "$BOOTDIR/uEnv.txt" <<EOF
firstboot=1
overlays=
ipaddr=$NET_IP
netmask=255.255.255.0
serverip=$NET_PC
optargs=earlycon=ns16550a,mmio32,0x02800000 console=tty1$QUIET
args_mmc=echo uEnv: beacon to $NET_PC; ping $NET_PC; setenv bootargs console=\${console} \${optargs} root=/dev/mmcblk\${mmcdev}p2 rw rootfstype=btrfs rootwait roottimeout=30 bootpart=/dev/mmcblk\${mmcdev}p1 firstboot=\${firstboot} init_fatal_sh=1
boot_mmc=run get_kern_mmc; run get_fdt_mmc; run get_initrd_mmc; booti \${loadaddr} \${initrdaddr}:\${filesize} \${fdtaddr}; echo booti failed; ping ${NET_PC%.*}.99
EOF

# ---------- 4. disk image ----------
log "create image $IMG"
rm -f "$IMG"; truncate -s "$IMG_SIZE" "$IMG"
# Same layout as T3's own (working) SD image: 128 MiB FAT32 boot partition with 512-byte clusters,
# hidden sectors 0 and 16/32 geometry. The AM67A boot ROM reads tiboot3.bin with its own small
# FAT driver; the mkfs.vfat defaults (4 KiB clusters, hidden=2048, 255/63) never booted.
parted -s "$IMG" mklabel msdos mkpart primary fat32 1MiB 129MiB set 1 boot on mkpart primary 129MiB 100%
LOOP=$(losetup --show -fP "$IMG")
# the partition nodes (loopNp1/p2) appear asynchronously via udev; under load (or right after a VM
# restart) mkfs could run before they exist ("unable to open /dev/loopNp1")
for i in $(seq 30); do [ -b "${LOOP}p1" ] && [ -b "${LOOP}p2" ] && break; partx -u "$LOOP" 2>/dev/null || true; udevadm settle 2>/dev/null || true; sleep 1; done
[ -b "${LOOP}p1" ] && [ -b "${LOOP}p2" ] || { echo "partitions of $LOOP did not appear"; exit 1; }
mkfs.vfat -F 32 -s 1 -h 0 -g 16/32 -n BOOT "${LOOP}p1"
mkfs.btrfs -f -L rootfs "${LOOP}p2"
mkdir -p /mnt/gem-root
mount -o compress=zstd "${LOOP}p2" /mnt/gem-root
# the build's own state files (/.stage1-done, /.kernel-deb, /.gpu-1, …) stay out of the image
rsync -aHAX --numeric-ids --exclude='/.stage*-done' --exclude='/.kernel-deb' --exclude='/.gpu-*' \
      --exclude='/.slim-*' "$ROOTFS"/ /mnt/gem-root/
mount "${LOOP}p1" /mnt/gem-root/boot/firmware
cp -r "$BOOTDIR"/. /mnt/gem-root/boot/firmware/
sync
umount /mnt/gem-root/boot/firmware; umount /mnt/gem-root
losetup -d "$LOOP"; LOOP=
log "compress (xz -$XZ_LEVEL)"
# -T0 = all cores; memory per thread: ~30 MB at -3, ~100 MB at -6, ~700 MB at -9 (too much for a 4 GB VM)
xz -T0 -"$XZ_LEVEL" -k -f "$IMG"
# bare file names, so that "sha256sum -c" works wherever the files are downloaded to
( cd "$(dirname "$IMG")" && sha256sum "$(basename "$IMG")" "$(basename "$IMG").xz" ) > "$IMG.sha256"
chown -R "${SUDO_UID:-1000}:${SUDO_GID:-1000}" "$OUT"   # give the output back to the user who ran sudo
ls -la "$OUT"
echo IMAGE_OK "$IMG"
