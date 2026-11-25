# Pardus 25 for the T3 Gemstone O1

[🇹🇷](README.tr.md)

This repository contains the scripts that build a Pardus 25 SD card image **from source** for the
T3 Gemstone O1 board (TI AM67A / J722S). The bootloader (TF-A, OP-TEE, U-Boot), the Linux kernel,
the initramfs and the Pardus root filesystem are all built with a single command. The output is not
an ISO; it is a `.img.xz` written straight to the SD card.

## Overview

- One-command build:  
  `./build.sh desktop` *(desktop)* or `./build.sh headless` *(headless)*.
- Kernel, selected with `--kernel`:  
  T3 6.12, Debian 7.2.12, kernel.org 6.18 LTS (patched/unpatched) and kernel.org 7.3.5 (patched/unpatched).  
  All of them share the same board definition (`board/dts/`) and the same Pardus userspace; only the kernel source and the patch set change.

- System size, selected with `--flavor`:  
  `full` *(full desktop)*, `lite` *(plain desktop)*, `minimal` *(no desktop)*.

- The default desktop kernel is kernel.org 6.18 LTS plus the HDMI patches. On the board, HDMI, the Pardus XFCE desktop and the GPU (Vulkan) all work. The headless setup uses the unpatched kernel.
- Measured on the headless image, 6.18 LTS: boots in about 15 seconds, about 298 MB of RAM idle.
- Login: user `pardus`, password `temppwd` *(you are asked for a new password at first login)*.

## Documentation

The detailed documents are in Turkish:

| Document | Contents |
|---|---|
| [docs/OZET.md](docs/OZET.md) | What is produced, and how to reproduce it |
| [docs/PROSEDUR.md](docs/PROSEDUR.md) | Step-by-step reproduction |
| [docs/HDMI-YAMALARI.md](docs/HDMI-YAMALARI.md) | The HDMI kernel patches; Debian 7.2, 6.18 LTS and 7.3 differences |
| [docs/BELGE.md](docs/BELGE.md) | Detailed technical document (rationale, solved problems) |
| [docs/SURUM-NOTLARI.md](docs/SURUM-NOTLARI.md) | Release notes for the produced images |

## Requirements

- A Pardus 25 (x86_64) computer or virtual machine *(or another Debian 13-based distribution)*.
  Recommended: 4 CPUs, 4–6 GB RAM, 60 GB of free disk.
- An internet connection *(sources and Pardus packages are downloaded)*.
- An SD card *(at least 16 GB)* and a card reader.

## Quick start

```bash
# 1. Dependencies
sudo apt-get update
sudo apt-get install -y git make bison flex bc swig libssl-dev libgnutls28-dev uuid-dev \
  python3-setuptools python3-pyelftools python3-dev python3-cryptography python3-yaml \
  python3-jsonschema yamllint device-tree-compiler u-boot-tools \
  debootstrap qemu-user-static binfmt-support \
  libncurses-dev libelf-dev libdw-dev lz4 lzop kpartx parted dosfstools e2fsprogs btrfs-progs \
  rsync ccache kmod cpio xz-utils zstd fakeroot dpkg-dev debhelper wget

# 2. Get the repository
git clone https://github.com/mlozturk/pardus-t3-gemstone.git gemstone
cd gemstone

# 3. Build
./build.sh desktop      # desktop image:  lite + 6.18 LTS + HDMI patches
# ./build.sh headless   # headless image: minimal + 6.18 LTS (unpatched)
```

When the build finishes it prints `BUILD_OK <image>`. Steps that already have their output are skipped, so a later run only rebuilds what changed.

## Build steps

`build.sh` runs four steps in order:

| Step | Script | First time | Produces |
|---|---|---|---|
| 1. Sources | `scripts/00-fetch-sources.sh` | ~20 min | compilers, U-Boot, TF-A, OP-TEE, TI firmware (versions from `versions.env`) |
| 2. Bootloader | `scripts/01-bootloader.sh` | ~3 min | `out/boot/tiboot3.bin`, `tispl.bin`, `u-boot.img` |
| 3. Kernel | `kernels/<name>/build.sh` (T3: `scripts/02-kernel.sh`) | 10–90 min | `kernels/<name>/out/` (`.deb`, `Image`, DTB) |
| 4. System + image | `scripts/03-rootfs-image.sh` (**sudo**) | ~60–75 min | `out/…-<flavor>-<date>-own-k<kernel>.img(.xz, .sha256)` |

The board definition (DTB) is rebuilt from `board/dts/` on every build. Log:
`out-<flavor>-<kernel>.log`. The steps can also be run individually (see [docs/PROSEDUR.md](docs/PROSEDUR.md)).

### Boot chain

```
ROM → tiboot3.bin (R5 SPL + TI firmware) → tispl.bin (TF-A, OP-TEE, A53 SPL) → u-boot.img → Image + DTB + initramfs → btrfs root filesystem
```

The BOOT partition is 128 MB FAT32 and carries these files in the layout the board expects.

## Configuration

```bash
./build.sh image --flavor <full|lite|minimal> --kernel <kernel> [options]
```

| Shortcut | Expands to |
|---|---|
| `./build.sh desktop` | `--flavor lite --kernel lts-hdmi` |
| `./build.sh headless` | `--flavor minimal --kernel mainline` |

Extra options:

| Option | Effect |
|---|---|
| `--rebuild-kernel` | Rebuild the kernel even if a package already exists |
| `--distro debian` | Debian 13 root filesystem instead of Pardus |
| `--release <version>` | Compress harder (`xz -6`) and collect into `release/<version>/`: images, `SHA256SUMS`, release notes, `BUILDINFO.txt` (`scripts/06-release.sh`) |
| `--xz <N>` | `.img.xz` compression level (default 3) |

### System size (`--flavor`)

| Size | Contents | Image |
|---|---|---|
| `full` | Pardus XFCE, LibreOffice, Firefox, development tools | ~12 GB |
| `lite` | Plain Pardus XFCE, Pardus tools, GPU (Vulkan) | ~8 GB |
| `minimal` | No desktop: SSH, networking, card tools, Python 3 | ~4 GB |

### Kernel (`--kernel`)

All kernels use the same board definition (`board/dts/`) and the same userspace; only the kernel
source and the applied patches differ. The HDMI patches (Tomi Valkeinen's tidss/AM62P series) bring
up the board's display subsystem (DSS); see
["Why we build our own kernel"](#why-we-build-our-own-kernel) below.

| `--kernel` | Source | HDMI | When to use |
|---|---|---|---|
| `lts-hdmi` | kernel.org 6.18 LTS (6.18.64) + 20 HDMI patches backported to 6.18 | yes | **Desktop, long-term.** Recommended desktop configuration; 6.18 LTS gets fixes until December 2028 |
| `mainline` | kernel.org 6.18 LTS (6.18.64), unpatched | no | **Headless, long-term.** Recommended headless configuration; smallest image |
| `stable-hdmi` | kernel.org 7.3.5 + 21 HDMI patches backported to 7.3 | yes | Trying a newer kernel on the desktop. Not LTS; ends when 7.4 ships |
| `stable` | kernel.org 7.3.5, unpatched | no | Trying a newer kernel headless. Not LTS |
| `debian` | Debian `linux 7.2.12-1~bpo13+1` + HDMI patches + GPU/VPU nodes from 7.4 (24 patches total) | yes | For staying on Debian's kernel package base; the previous desktop kernel |
| `t3` | Board vendor T3's 6.12 kernel ([v6.12.24-ti-arm64](https://github.com/t3gemstone/linux/tree/v6.12.24-ti-arm64-r43-t3-gem-o1)) | yes | Comparison with / when you need the vendor kernel's behaviour |

Build command for each configuration:

```bash
# Desktop (HDMI), long-term 6.18 LTS — default
./build.sh desktop                              # = --flavor lite --kernel lts-hdmi

# Headless, long-term 6.18 LTS — default
./build.sh headless                             # = --flavor minimal --kernel mainline

# Newer kernel (7.3.5, not LTS)
./build.sh desktop  --kernel stable-hdmi
./build.sh headless --kernel stable

# Debian 7.2.12-based desktop kernel
./build.sh desktop  --kernel debian

# Board vendor T3's 6.12 kernel
./build.sh image --flavor lite --kernel t3
```

Kernel patches live under `kernels/<name>/patches/` and are applied with `git am` during the build.
Because each kernel series may need different patches (e.g. adapting the HDMI/tidss patches to the
6.18 and 7.3 trees), patches are kept per series; if one does not apply, the build stops at the
`git am` step. All version numbers are in one file: [versions.env](versions.env). The board
definition is shared by all: [board/dts/README.md](board/dts/README.md).

## Directory layout

```
gemstone/
├── build.sh             one-command build (this repo)
├── versions.env         every pinned version (this repo)
├── scripts/             step scripts 00–06 (this repo)
├── board/dts/           board definition (DTS), one source for all kernels (this repo)
├── board/               on-board kernel update script (this repo)
├── kernels/<name>/      per-kernel build.sh and patches/ (this repo);
│                        src/, build/, out/ appear during the build (not in the repo)
├── patches/             patch for the T3 kernel (this repo)
├── docs/                detailed documents (this repo)
│
├── gcc-…-nolibc/        ┐
├── u-boot/              │
├── linux/               │  downloaded by 00-fetch-sources.sh
├── trusted-firmware-a/  │  (not in the repo)
├── optee_os/            │
├── ti-linux-firmware/   ┘
│
├── build/
│   ├── rootfs-pardus-…-<flavor>/  ← 03: Pardus root filesystem (separate folder per flavor)
│   └── bootfs/                    ← 03: files for the BOOT partition
└── out/
    ├── boot/            ← 01 and 02: bootloader, kernel, DTB
    ├── kernel/          ← kernel .deb packages
    └── …-<flavor>-<date>-own-k<kernel>.img(.xz)   ← 03: SD card image
release/<version>/       ← 06: release folder (images hard-link into out/, no extra space)
```

### How the image is created

`scripts/03-rootfs-image.sh`:

1. Installs an empty arm64 Pardus/Debian system with `debootstrap` (ARM programs run under `qemu`).
2. Installs the Pardus packages, the selected kernel and the initramfs.
3. Adds the user, the network setting (static IP `10.42.0.12`) and the first-boot services.
4. Opens a two-partition image — partition 1 BOOT (128 MB FAT32), partition 2 rootfs (btrfs) —
   copies the files in, and compresses the image with `.xz`.

- `10.42.0.12` is the default address. `./build.sh` cannot set a different one; run  
  `sudo NET_IP=… NET_GW=… NET_PC=… ./scripts/03-rootfs-image.sh …`.

- The root filesystem directory is reused on the next build. To start over, run  
  `sudo rm build/rootfs-pardus-*/.stage1-done`.

## Writing to the SD card

```bash
lsblk                                           # find the card's name (e.g. sdb)
sudo ./scripts/04-flash-sd.sh /dev/sdX          # writes and verifies the newest image
sudo ./scripts/04-flash-sd.sh /dev/sdX minimal  # writes the newest image whose name contains "minimal"
```

Instead of an image name you can give a file path (`.img` or `.img.xz`) or nothing (the newest
image). Before writing, it is checked against the neighbouring `.sha256`. **Choose `/dev/sdX`
carefully: the wrong disk gets erased.** The `out/*.img.xz` file can also be written from another
computer with balenaEtcher or Raspberry Pi Imager.

## Booting the card

1. Insert the card, connect HDMI and Ethernet, apply power.
2. The Pardus login screen comes up in about 25 seconds (a `minimal` image has no display; go to step 3).  
   Log in as `pardus` / `temppwd`.
3. To connect over the network, set your computer's Ethernet address to `10.42.0.11/24`:
   `ssh pardus@10.42.0.12`.

On first boot the system expands itself to the whole SD card.

## Updating the kernel

### Moving to a newer LTS release

kernel.org ships fixes for the 6.18 series until December 2028. To move to a newer one, update three
lines in `versions.env` on the build machine — `MAINLINE_VERSION`, `MAINLINE_SHA256` (its line in
<https://cdn.kernel.org/pub/linux/kernel/v6.x/sha256sums.asc>) and `MAINLINE_PKGVER` — then rebuild:

```bash
./build.sh desktop  --rebuild-kernel   # new desktop (HDMI) kernel + image
./build.sh headless --rebuild-kernel   # new headless kernel + image
```

`lts-hdmi` and `mainline` use the same `versions.env` lines; one change updates both. Because only
fixes go into an LTS series, the HDMI patches usually apply unchanged.

### Installing on the card (without rewriting the SD card)

When a new kernel has been built, it can be installed over SSH without pulling the card:

```bash
KERNEL=lts-hdmi scripts/05-kernel-deploy.sh 10.42.0.12    # desktop 6.18 LTS (HDMI)
KERNEL=mainline scripts/05-kernel-deploy.sh 10.42.0.12    # headless 6.18 LTS
KERNEL=debian   scripts/05-kernel-deploy.sh 10.42.0.12    # Debian 7.2.12 desktop kernel
```

If `KERNEL` is not set, the value in the `.kernel` file is used, or `lts-hdmi` if there is none.
The vendor (T3) 6.12 kernel cannot be deployed this way; rewrite the SD card for it. The script
sends the package to the card, installs it with `gemstone-kernel-update`, reboots, and saves the
boot log (`dmesg`) under `kernels/<name>/`. The old kernel is kept on the card under
`/var/backups/gemstone-boot/`; if something breaks, roll back with
`sudo gemstone-kernel-update --restore`. The one-time setup on every freshly written card (SSH key
and a limited `sudo` permission) is described in
[docs/BELGE.md §22](docs/BELGE.md#22-çekirdeği-kartta-güncellemek-ssh-ile-sd-kartı-yazmadan).

## Why we build our own kernel

Debian's (and Pardus's) ready-made Linux kernel boots on this board but gives **no HDMI display**.
So we build it ourselves, adding the patches that enable display support and have not landed in
mainline Linux yet.

### Which part is the problem?

The problem is not the board vendor or the HDMI chip; it is inside the display subsystem (DSS) of
the board's processor, the **TI AM67A** (J722S):

```
[ TI AM67A processor ]                          [ separate chip ]        [ socket ]
  └─ DSS (display unit) ──parallel video──→      SiI9022 (HDMI bridge) ──→ HDMI
     not supported in mainline Linux             supported
```

When Linux boots it reads the board's hardware description, in which every part has an identity tag.
Our display unit's tag is `ti,am62p52-dss`. The display driver (`tidss`) only drives the tags in its
list; a part not in the list is never started.

| Chips the `tidss` driver knows | Mainline / Debian | TI / T3 kernel | Our patched kernel |
|---|---|---|---|
| AM625, AM62A, AM65x, J721E, K2G | yes | yes | yes |
| AM62L | no | yes | yes |
| **AM62P / J722S / AM67A** (`ti,am62p52-dss`) | no | yes | yes |

Because this support has not landed in mainline Linux (kernel.org) yet, no Debian version — 6.12,
7.2, 7.3 or linux-next — drives the AM67A display unit.

### Our approach and roadmap

- Desktop images are built with the HDMI patches that enable the TI parts Debian leaves disabled.
  Because the board definition comes from our own source (`board/dts/`), the system is independent of
  both the board vendor (T3) and TI's own kernel.
- The HDMI patches have been sent to the mainline Linux development branch and are not accepted yet.
  The GPU/VPU nodes have been accepted and will arrive with 7.4.
- Once the patches land in mainline and reach Debian, we can switch to Debian's ready-made kernel; at
  that point building the kernel from source is no longer needed and updates come with `apt upgrade`.

### Sources

- **Tomi Valkeinen** (maintainer of the `tidss` driver), *"drm/tidss: Add BeagleY-AI display support
  (and some more)"*: adds display support for AM62P and J722S; tested with HDMI display and audio on
  the BeagleY-AI. →
  [v3](https://lkml.iu.edu/2605.3/09688.html) ·
  [v2](https://lists.infradead.org/pipermail/linux-arm-kernel/2026-May/1129190.html) ·
  [v1](https://patchew.org/linux/20260420-beagley-ai-display-v1-0-f628543dfd14@ideasonboard.com/)
- **Swamil Jain**, *"Add Display support for AM62P SoC"*: adds the AM62P display unit's tag to the
  driver. →
  [v3 3/3](https://lkml.org/lkml/2026/1/7/1505) ·
  [v4](https://ratatoskr.run/lkml/2026/01/3371934/t)
- **BeagleBoard forum**: the status of display support on the BeagleY-AI, which uses the same
  processor. →
  [Raspberry Pi Touch Display 2 on BeagleY-AI](https://forum.beagleboard.org/t/raspberry-pi-touch-display-2-5-inch-on-beagley-ai-black-screen-after-successful-panel-init/44055) ·
  [Armbian and Working Release / BeagleY-AI](https://forum.beagleboard.org/t/armbian-and-working-release-beagley-ai-with-usb-2-and-or-usb-3/44174)
- To track the patch status: <https://lore.kernel.org/dri-devel/?q=am62p+dss>

Detailed comparison and decision table (Turkish):
[docs/BELGE.md §20](docs/BELGE.md#20-neden-debianın-hazır-kernelini-kullanamıyoruz-kernel-kaynağı-kararı).

## Troubleshooting

If the card does not boot, the boot stages and solved problems: [docs/BELGE.md](docs/BELGE.md).
Step-by-step procedure: [docs/PROSEDUR.md](docs/PROSEDUR.md).

## License

The scripts, patches and documentation in this repository are licensed under **GPL-2.0-or-later**
(see [`LICENSE`](LICENSE)). Components downloaded during the build (Linux, U-Boot, TF-A, OP-TEE,
TI firmware, Pardus/Debian packages) come under their own licenses and are not part of this
repository.
