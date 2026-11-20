# Pardus 25 for the T3 Gemstone O1

[🇹🇷](README.tr.md)

This repository builds a Pardus 25 SD card image for the T3 Gemstone O1 board (TI AM67A) from
source. The bootloader, the Linux kernel, the initramfs, and the Pardus system itself are prepared
by the scripts here.

- The kernel is built from Debian's own source: **`7.2.12-gemstone+`**. The HDMI patches bring up
  display and sound, Ethernet, Wi-Fi, and Bluetooth on the board. *(T3's [Linux 6.12 kernel](https://github.com/t3gemstone/linux/tree/v6.12.24-ti-arm64-r43-t3-gem-o1) can be used as well.)*
- Login: user `pardus`, password `temppwd` *(a new password is required at first login)*.


## Requirements

- A computer or virtual machine with Linux installed. *(4 CPUs, 6 GB of RAM, and 60 GB of free disk make the build comfortable.)*
- An internet connection *(sources and Pardus packages will be downloaded)*
- An SD card *(at least 16 GB)* and a card reader.

## 1. Setup

```bash
sudo apt-get update
sudo apt-get install -y git make bison flex bc swig libssl-dev libgnutls28-dev uuid-dev \
  python3-setuptools python3-pyelftools python3-dev python3-cryptography python3-yaml \
  python3-jsonschema yamllint device-tree-compiler u-boot-tools \
  debootstrap qemu-user-static binfmt-support \
  libncurses-dev libelf-dev libdw-dev lz4 lzop kpartx parted dosfstools e2fsprogs btrfs-progs \
  rsync ccache kmod cpio xz-utils zstd fakeroot dpkg-dev debhelper wget

git clone https://github.com/mlozturk/pardus-t3-gemstone.git gemstone
cd gemstone
./scripts/00-fetch-sources.sh
```

- `00-fetch-sources.sh` downloads the compiler and the bootloader sources *(U-Boot, TF-A, OP-TEE, TI firmware)*. T3's 6.12 kernel is also downloaded into `linux/`; the next step builds it with `scripts/02-kernel.sh`. It finishes by printing `SOURCES_OK`.

The kernel that runs on the board is built from Debian's `7.2.12` source (`7.2.12-gemstone+`).
`kernels/debian/build.sh` downloads that source, applies the HDMI patches in `kernels/debian/patches/`, and builds it.

