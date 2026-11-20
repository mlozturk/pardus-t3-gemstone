# T3 Gemstone O1 için Pardus 25

[🇬🇧](README.md)

Bu depo, T3 Gemstone O1 kartı (TI AM67A) için Pardus 25 SD kart imajını kaynak koddan derleyip
üretir. Bootloader, Linux çekirdeği, initramfs ve Pardus sisteminin kendisi buradaki scriptler yardımı ile
hazırlanır.

- Çekirdek, Debian'ın kendi kaynağından derlenmiştir **`7.2.12-gemstone+`**. HDMI yamalarıyla kartta görüntü ve ses, Ethernet, Wi-Fi ve Bluetooth çalışır hale getirilmiştir. *(T3'ün [linux 6.12 çekirdeği](https://github.com/t3gemstone/linux/tree/v6.12.24-ti-arm64-r43-t3-gem-o1) de kullanılabilir.)*
- Giriş: kullanıcı `pardus`, şifre `temppwd` *(ilk girişte yeni şifre istenir)*.


## Gerekenler

- Linux kurulu bir bilgisayar ya da sanal makine. *(Rahat derlemek için 4 işlemci, 6 GB RAM ve 60 GB boş disk iyi olur)*
- İnternet bağlantısı *(kaynaklar ve Pardus paketleri indirilecek)*
- SD kart *(en az 16 GB)* ve kart okuyucu.

## 1. Kurulum

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

- `00-fetch-sources.sh` derleyiciyi ve bootloader kaynaklarını indirir *(U-Boot, TF-A, OP-TEE, TI firmware)*. Çekirdek olarak T3'ün 6.12'si de iner (`linux/` klasörü); sonraki aşamada `scripts/02-kernel.sh` ile derlenir. Bitince `SOURCES_OK` yazar.

Kartta çalışan çekirdek Debian'ın `7.2.12` kaynağından derlenir (`7.2.12-gemstone+`).
`kernels/debian/build.sh` bu kaynağı indirir, `kernels/debian/patches/` içindeki HDMI yamalarını uygular ve derler.
