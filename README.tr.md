# T3 Gemstone O1 için Pardus 25

[🇬🇧](README.md)

Bu depo, T3 Gemstone O1 kartı (TI AM67A / J722S) için Pardus 25 SD kart imajını kaynak koddan
üreten betikleri içerir. Bootloader (TF-A, OP-TEE, U-Boot), Linux çekirdeği, initramfs ve Pardus
kök dosya sistemi tek komutla derlenir. Çıktı bir ISO değil; SD karta yazılan `.img.xz` dosyasıdır.

## Genel bakış

- Tek komutla derleme:  
    `./build.sh desktop` _(masaüstü)_ veya `./build.sh headless` _(ekransız)_.
- Çekirdek yapılandırması `--kernel` ile seçilebilir:  
     T3 6.12, Debian 7.2.12, kernel.org 6.18 LTS (yamalı/yamasız), kernel.org 7.3.5
  (yamalı/yamasız) ve Debian trixie 6.12 (yamalı/yamasız).
   Hepsi aynı kart tanımını
  (`board/dts/`) ve aynı Pardus kullanıcı alanını paylaşır; yalnız çekirdek kaynağı ve yama kümesi
  değişir.

- Sistem boyutu `--flavor` ile seçilebilir:  
   `full` _(tam masaüstü)_, `lite` _(sade masaüstü)_, `minimal` _(masaüstü yok)_.

- Varsayılan masaüstü çekirdeği kernel.org 6.18 LTS + HDMI yamalarıdır; kartta HDMI görüntü,
  Pardus XFCE masaüstü ve GPU (Vulkan) çalışır. Ekransız yapılandırmada yamasız çekirdek kullanılır.
- Ölçülen performans (ekransız, 6.18 LTS): sistem ~15 saniyede açılır, boşta ~298 MB bellek kullanır.
- Giriş: kullanıcı `pardus`, şifre `temppwd` *(ilk girişte yeni şifre istenir)*.

## Belgeler

| Belge | İçerik |
|---|---|
| [docs/OZET.md](docs/OZET.md) | Neler üretiliyor, nasıl yeniden üretiliyor?|
| [docs/PROSEDUR.md](docs/PROSEDUR.md) | Adım adım yeniden üretme |
| [docs/HDMI-YAMALARI.md](docs/HDMI-YAMALARI.md) | HDMI çekirdek yamaları; Debian 7.2, 6.18 LTS ve 7.3 farkları |
| [docs/BELGE.md](docs/BELGE.md) | Ayrıntılı teknik belge (gerekçeler, çözülen sorunlar) |
| [docs/SURUM-NOTLARI.md](docs/SURUM-NOTLARI.md) | Üretilen imajların sürüm notu |

## Gereksinimler

- Pardus 25 (x86_64) bir bilgisayar ya da sanal makine *(Debian 13 tabanlı bir dağıtım)*.
  Önerilen: 4 işlemci, 4–6 GB RAM, 60 GB boş disk.
- İnternet bağlantısı *(kaynaklar ve Pardus paketleri indirilir)*.
- SD kart *(en az 16 GB)* ve kart okuyucu.

## Hızlı başlangıç

```bash
# 1. Bağımlılıklar
sudo apt-get update
sudo apt-get install -y git make bison flex bc swig libssl-dev libgnutls28-dev uuid-dev \
  python3-setuptools python3-pyelftools python3-dev python3-cryptography python3-yaml \
  python3-jsonschema yamllint device-tree-compiler u-boot-tools \
  debootstrap qemu-user-static binfmt-support \
  libncurses-dev libelf-dev libdw-dev lz4 lzop kpartx parted dosfstools e2fsprogs btrfs-progs \
  rsync ccache kmod cpio xz-utils zstd fakeroot dpkg-dev debhelper wget

# 2. Depoyu al
git clone https://github.com/mlozturk/pardus-t3-gemstone.git gemstone
cd gemstone

# 3. Derle
./build.sh desktop      # masaüstü imajı: lite + 6.18 LTS + HDMI yamaları
# ./build.sh headless   # ekransız imaj:  minimal + 6.18 LTS (yamasız)
```

Derleme bitince `BUILD_OK <imaj>` yazar. Sonucu mevcut olan adımları atladığı için ilk derlemeden sonra yeniden çalıştırmak sadece değişen şeyleri yeniden derler.

## Derleme adımları

`build.sh` sırasıyla dört adımı çalıştırır:

| Adım | Betik | İlk seferde | Üretilen |
|---|---|---|---|
| 1. Kaynaklar | `scripts/00-fetch-sources.sh` | ~20 dk | derleyiciler, U-Boot, TF-A, OP-TEE, TI firmware (sürümler `versions.env`'den) |
| 2. Bootloader | `scripts/01-bootloader.sh` | ~3 dk | `out/boot/tiboot3.bin`, `tispl.bin`, `u-boot.img` |
| 3. Çekirdek | `kernels/<ad>/build.sh` (T3 için `scripts/02-kernel.sh`) | 10–90 dk | `kernels/<ad>/out/` (`.deb`, `Image`, DTB) |
| 4. Sistem + imaj | `scripts/03-rootfs-image.sh` (**sudo**) | ~60–75 dk | `out/…-<boyut>-<tarih>-own-k<çekirdek>.img(.xz, .sha256)` |

Kart tanımı (DTB) her derlemede `board/dts/`'den yeniden üretilir. Log:
`out-<boyut>-<çekirdek>.log`. Adımlar tek tek de çalıştırılabilir (bkz. [docs/PROSEDUR.md](docs/PROSEDUR.md)).

### Açılış zinciri

```
ROM → `tiboot3.bin` (R5 SPL + TI firmware) → `tispl.bin` (TF-A, OP-TEE,
A53 SPL) → `u-boot.img` → `Image` + DTB + initramfs → btrfs kök dosya sistemi.
```
BOOT bölümü 128 MB FAT32'dir ve bu dosyaları kartın beklediği düzende taşır.

## Yapılandırma

```bash
./build.sh image --flavor <full|lite|minimal> --kernel <çekirdek> [seçenekler]
```


| Kısayol | Karşılığı |
|---|---|
| `./build.sh desktop` | `--flavor lite --kernel lts-hdmi` |
| `./build.sh headless` | `--flavor minimal --kernel mainline` |

Ek seçenekler:

| Seçenek | Etkisi |
|---|---|
| `--rebuild-kernel` | Paket mevcut olsa bile çekirdeği yeniden derler |
| `--distro debian` | Pardus yerine Debian 13 kök dosya sistemi |
| `--release <sürüm>` | Daha sıkı sıkıştırma (`xz -6`) ve `release/<sürüm>/` klasörü: imajlar, `SHA256SUMS`, sürüm notu, `BUILDINFO.txt` (`scripts/06-release.sh`) |
| `--xz <N>` | `.img.xz` sıkıştırma düzeyi (varsayılan 3) |

### Sistem boyutu (`--flavor`)

| Boyut | İçerik | İmaj |
|---|---|---|
| `full` | Pardus XFCE, LibreOffice, Firefox, geliştirme araçları | ~12 GB |
| `lite` | Sade Pardus XFCE, Pardus araçları, GPU (Vulkan) | ~8 GB |
| `minimal` | Masaüstü yok: SSH, ağ, kart araçları, Python 3 | ~4 GB |

### Çekirdek (`--kernel`)

Tüm çekirdekler aynı kart tanımını (`board/dts/`) ve aynı userspace'i kullanır; fark yalnız çekirdek
kaynağında ve uygulanan yamalardadır. HDMI yamaları (Tomi Valkeinen'in tidss/AM62P serisi) kartın
görüntü birimini (DSS) çalışır hale getirir; ayrıntı için aşağıdaki
["Neden kendi çekirdeğimizi derliyoruz?"](#neden-kendi-çekirdeğimizi-derliyoruz) bölümüne bakın.

| `--kernel` | Kaynak | HDMI | Ne zaman kullanılır |
|---|---|---|---|
| `lts-hdmi` | kernel.org 6.18 LTS (6.18.64) + 6.18'e taşınmış 20 HDMI yaması | var | **Masaüstü, uzun destek.** Önerilen masaüstü yapılandırması; 6.18 LTS'e Aralık 2028'e kadar düzeltme gelir |
| `mainline` | kernel.org 6.18 LTS (6.18.64), yamasız | yok | **Ekransız, uzun destek.** Önerilen ekransız yapılandırması; en küçük imaj |
| `stable-hdmi` | kernel.org 7.3.5 + 7.3'e taşınmış 21 HDMI yaması | var | Masaüstünde daha yeni çekirdek denemek. LTS değil; 7.4 çıkınca kapanır |
| `stable` | kernel.org 7.3.5, yamasız | yok | Ekransızda daha yeni çekirdek denemek. LTS değil |
| `trixie-hdmi` | Debian trixie `linux 6.12.118-1` (Pardus 25'in kullandığı çekirdek) + 6.18'den ekran/GPU sürücüleri + HDMI/DTS yamaları (14 yama) | var | Pardus 25'in kendi çekirdeğiyle masaüstü |
| `trixie` | Debian trixie `linux 6.12.118-1`, Debian ayarı + kart sürücüleri | yok | Pardus 25'in kendi çekirdeğiyle ekransız |
| `debian` | Debian `linux 7.2.12-1~bpo13+1` + HDMI yamaları + 7.4'ten GPU/VPU tanımı (toplam 24 yama) | var | Debian'ın çekirdek paketi tabanında kalmak isteyenler için; önceki masaüstü çekirdeği |
| `t3` | Kart üreticisi T3'ün 6.12 çekirdeği ([v6.12.24-ti-arm64](https://github.com/t3gemstone/linux/tree/v6.12.24-ti-arm64-r43-t3-gem-o1)) | var | Üretici çekirdeğiyle karşılaştırma / vendor davranışına ihtiyaç duyulduğunda |

Her yapılandırmayı derleme komutu:

```bash
# Masaüstü (HDMI), uzun destekli 6.18 LTS — varsayılan
./build.sh desktop                              # = --flavor lite --kernel lts-hdmi

# Ekransız, uzun destekli 6.18 LTS — varsayılan
./build.sh headless                             # = --flavor minimal --kernel mainline

# Daha yeni çekirdek (7.3.5, LTS değil)
./build.sh desktop  --kernel stable-hdmi
./build.sh headless --kernel stable

# Pardus 25'in kendi Debian trixie 6.12 çekirdeği
./build.sh desktop  --kernel trixie-hdmi
./build.sh headless --kernel trixie

# Debian 7.2.12 tabanlı masaüstü çekirdeği
./build.sh desktop  --kernel debian

# Kart üreticisi T3'ün 6.12 çekirdeği
./build.sh image --flavor lite --kernel t3
```

Çekirdek yamaları `kernels/<ad>/patches/` altındadır ve derleme sırasında `git am` ile uygulanır.
Her çekirdek serisi farklı yama gerektirebildiği için (örneğin HDMI/tidss yamalarının 6.18 ve 7.3
ağaçlarına uyarlanması), yamalar seri bazında ayrı tutulur; bir yama uymazsa derleme `git am`
adımında durur. Bütün sürüm numaraları tek dosyadadır: [versions.env](versions.env). Kart tanımı
hepsinde ortaktır: [board/dts/README.md](board/dts/README.md).

## Dizin yapısı

```
gemstone/
├── build.sh             tek komutluk derleme (bu depo)
├── versions.env         sabitlenen bütün sürümler (bu depo)
├── scripts/             adım betikleri 00–06 (bu depo)
├── board/dts/           kart tanımı (DTS), bütün çekirdekler için tek kaynak (bu depo)
├── board/               kartta çalışan çekirdek güncelleme betiği (bu depo)
├── kernels/<ad>/        çekirdek başına build.sh ve patches/ (bu depo);
│                        src/, build/, out/ derlemede oluşur (depoya girmez)
├── patches/             T3 çekirdeği için yama (bu depo)
├── docs/                ayrıntılı belgeler (bu depo)
│
├── gcc-…-nolibc/        ┐
├── u-boot/              │
├── linux/               │  00-fetch-sources.sh indirir
├── trusted-firmware-a/  │  (depoya girmez)
├── optee_os/            │
├── ti-linux-firmware/   ┘
│
├── build/
│   ├── rootfs-pardus-…-<boyut>/   ← 03: Pardus kök dosya sistemi (boyut başına ayrı klasör)
│   └── bootfs/                    ← 03: BOOT bölümüne girecek dosyalar
└── out/
    ├── boot/            ← 01 ve 02: bootloader, kernel, DTB
    ├── kernel/          ← kernel .deb paketleri
    └── …-<boyut>-<tarih>-own-k<çekirdek>.img(.xz)   ← 03: SD kart imajı
release/<sürüm>/         ← 06: yayın klasörü (imajlar out/'a sabit bağlantı, ek yer tutmaz)
```
### İmaj nasıl oluşur

`scripts/03-rootfs-image.sh`:

1. `debootstrap` ile boş bir arm64 Pardus/Debian sistemi kurar (ARM programları `qemu` ile çalışır).
2. Pardus paketlerini, seçilen çekirdeği ve initramfs'i kurar.
3. Kullanıcıyı, ağ ayarını (sabit IP `10.42.0.12`) ve ilk açılış servislerini ekler.
4. İki bölümlü bir imaj açar — 1. bölüm BOOT (128 MB FAT32), 2. bölüm rootfs (btrfs) — dosyaları
   kopyalar ve imajı `.xz` ile sıkıştırır.

-  `10.42.0.12` varsayılan adrestir; başka bir adres için `./build.sh` yetmez,  
 `sudo NET_IP=… NET_GW=… NET_PC=… ./scripts/03-rootfs-image.sh …` çalıştırılır.

-  Kök dosya sistemi klasörü sonraki derlemede yeniden kullanılır; sıfırdan kurmak için  
`sudo rm build/rootfs-pardus-*/.stage1-done`

## SD karta yazma

```bash
lsblk                                           # kartın adını bulun (ör. sdb)
sudo ./scripts/04-flash-sd.sh /dev/sdX          # en yeni imajı yazar ve doğrular
sudo ./scripts/04-flash-sd.sh /dev/sdX minimal  # adında "minimal" geçen en yeni imajı yazar
```

İmaj adı yerine dosya yolu (`.img` veya `.img.xz`) ya da hiçbir şey (en yeni imaj) verilebilir.
Yazmadan önce yanındaki `.sha256` ile denetlenir. **`/dev/sdX`'i dikkatle seçilmeli, yanlış disk
silinebilir.**   
`out/*.img.xz` dosyası başka bir bilgisayardan balenaEtcher veya Raspberry Pi Imager ile
de yazılabilir.

## Kartı açma

1. Kartı takın, HDMI ve Ethernet'i bağlayın, güç verin.
2. ~25 saniyede Pardus giriş ekranı gelir (`minimal` imajda ekran yoktur, 3. adıma geçin).  
   Giriş: `pardus` / `temppwd`.
3. Ağdan bağlanmak için bilgisayarın Ethernet adresini `10.42.0.11/24` yapın:  
   `ssh pardus@10.42.0.12`.

İlk açılışta kök bölüm SD kartın kalanına genişler.

## Çekirdeği güncelleme

### Yeni bir LTS sürümüne geçmek

kernel.org 6.18 serisine Aralık 2028'e kadar düzeltme sürümleri çıkar. Yenisine geçmek için derleme
makinesinde `versions.env` içindeki üç satır güncellenir — `MAINLINE_VERSION`, `MAINLINE_SHA256`
(karşılığı <https://cdn.kernel.org/pub/linux/kernel/v6.x/sha256sums.asc> içinde) ve `MAINLINE_PKGVER`
— sonra yeniden derlenir:

```bash
./build.sh desktop  --rebuild-kernel   # yeni masaüstü (HDMI) çekirdeği + imaj
./build.sh headless --rebuild-kernel   # yeni ekransız çekirdeği + imaj
```

`lts-hdmi` ve `mainline` aynı `versions.env` satırlarını kullanır; tek değişiklikle ikisi birden
güncellenir. LTS serisine yalnız düzeltmeler girdiği için HDMI yamaları genelde değişmeden uyar.

### Kartta kurma (SD kartı yeniden yazmadan)

Yeni bir çekirdek derlendiğinde kartı sökmeden SSH ile kurulabilir:

```bash
KERNEL=lts-hdmi scripts/05-kernel-deploy.sh 10.42.0.12    # masaüstü 6.18 LTS (HDMI)
KERNEL=mainline scripts/05-kernel-deploy.sh 10.42.0.12    # ekransız 6.18 LTS
KERNEL=debian   scripts/05-kernel-deploy.sh 10.42.0.12    # Debian 7.2.12 masaüstü çekirdeği
```

`KERNEL` verilmezse `.kernel` dosyasındaki değer, o da yoksa `lts-hdmi` kullanılır.   
Üretici (T3) 6.12 çekirdeği bu yolla kurulamaz; onun için SD kartı yeniden yazın. Betik paketi karta gönderir,
kartta `gemstone-kernel-update` ile kurar, yeniden başlatır ve açılış günlüğünü (`dmesg`)
`kernels/<ad>/` altına kaydeder. Eski çekirdek kartta `/var/backups/gemstone-boot/` içinde saklanır;
sorun olursa `sudo gemstone-kernel-update --restore` ile geri alınabilir. Yeni yazılmış her kartta
bir kez yapılacak hazırlık (SSH anahtarı ve sınırlı `sudo` izni)
[docs/BELGE.md §22](docs/BELGE.md#22-çekirdeği-kartta-güncellemek-ssh-ile-sd-kartı-yazmadan)
bölümünde anlatılır.

## Neden kendi çekirdeğimizi derliyoruz?

Debian'ın (ve Pardus'un) hazır Linux çekirdeği bu kartta açılır ama **HDMI'dan görüntü vermez**.
Bu yüzden görüntü desteğini ekleyen ve henüz ana Linux'a girmemiş yamaları çekirdek kaynağının
üstüne koyarak kendimiz derliyoruz.

### Sorun hangi parçada?

Sorun kartın üreticisinde ya da HDMI yongasında değil; kartın işlemcisi **TI AM67A**'nın (J722S)
içindeki görüntü biriminde (DSS, Display Subsystem):

```
[ TI AM67A işlemcisi ]                          [ ayrı yonga ]           [ soket ]
  └─ DSS (görüntü birimi) ──paralel görüntü──→  SiI9022 (HDMI köprüsü) ──→ HDMI
     ana Linux'ta destek yok                    destek var
```

Linux açılırken kartın donanım tarifini okur; her parçanın bir kimlik etiketi vardır. Kartımızın
görüntü biriminin etiketi `ti,am62p52-dss`. Görüntü sürücüsü (`tidss`) yalnızca listesindeki
etiketleri çalıştırır; listede olmayan parça hiç başlatılmaz.

| `tidss` sürücüsünün tanıdığı yongalar | Ana Linux / Debian | TI / T3 çekirdeği | Yamalı çekirdeğimiz |
|---|---|---|---|
| AM625, AM62A, AM65x, J721E, K2G | var | var | var |
| AM62L | yok | var | var |
| **AM62P / J722S / AM67A** (`ti,am62p52-dss`) | yok | var | var |

Bu destek ana Linux'a (kernel.org) henüz girmediği için Debian'ın hiçbir sürümünde — 6.12, 7.2,
7.3 ve linux-next dahil — AM67A görüntü birimi çalışmaz.

### Yaklaşımımız ve yol haritası

- Masaüstü imajları, Debian'ın kapalı bıraktığı TI parçalarını açan HDMI yamalarıyla derlenir.
  Kart tanımı kendi kaynağımızdan (`board/dts/`) geldiği için sistem hem kart üreticisi T3'ten hem
  TI'ın özel çekirdeğinden bağımsızdır.
- HDMI yamaları ana Linux'un geliştirme dalına gönderildi, henüz kabul edilmedi. GPU/VPU tanımları
  kabul edildi ve 7.4 ile gelecek.
- Yamalar ana Linux'a girip Debian'a ulaştığında Debian'ın hazır çekirdeğine geçilebilir; o noktada
  çekirdeği kaynaktan derlemek gerekmez, güncellemeler `apt upgrade` ile gelir.

### Kaynaklar

- **Tomi Valkeinen** (`tidss` sürücüsünün bakımcısı), *"drm/tidss: Add BeagleY-AI display support
  (and some more)"*: AM62P ve J722S için görüntü desteği ekler; BeagleY-AI'de HDMI görüntü ve ses
  ile test edilmiştir. →
  [v3](https://lkml.iu.edu/2605.3/09688.html) ·
  [v2](https://lists.infradead.org/pipermail/linux-arm-kernel/2026-May/1129190.html) ·
  [v1](https://patchew.org/linux/20260420-beagley-ai-display-v1-0-f628543dfd14@ideasonboard.com/)
- **Swamil Jain**, *"Add Display support for AM62P SoC"*: sürücüye AM62P görüntü biriminin etiketini
  ekler. →
  [v3 3/3](https://lkml.org/lkml/2026/1/7/1505) ·
  [v4](https://ratatoskr.run/lkml/2026/01/3371934/t)
- **BeagleBoard forumu**: aynı işlemciyi kullanan BeagleY-AI'de görüntü desteğinin durumu. →
  [Raspberry Pi Touch Display 2 on BeagleY-AI](https://forum.beagleboard.org/t/raspberry-pi-touch-display-2-5-inch-on-beagley-ai-black-screen-after-successful-panel-init/44055) ·
  [Armbian and Working Release / BeagleY-AI](https://forum.beagleboard.org/t/armbian-and-working-release-beagley-ai-with-usb-2-and-or-usb-3/44174)
- Yamaların durumunu izlemek: <https://lore.kernel.org/dri-devel/?q=am62p+dss>

Ayrıntılı karşılaştırma ve karar tablosu:
[docs/BELGE.md §20](docs/BELGE.md#20-neden-debianın-hazır-kernelini-kullanamıyoruz-kernel-kaynağı-kararı).

## Sorun giderme

Kart açılmazsa, açılış aşamaları ve çözülmüş sorunlar:   [docs/BELGE.md](docs/BELGE.md).  
Adım adım yordam: [docs/PROSEDUR.md](docs/PROSEDUR.md).

## Lisans

Bu depodaki betikler, yamalar ve belgeler **GPL-2.0-or-later** ile lisanslanmıştır (bkz.
[`LICENSE`](LICENSE)). Derleme sırasında indirilen bileşenler (Linux, U-Boot, TF-A, OP-TEE,
TI firmware, Pardus/Debian paketleri) kendi lisanslarıyla gelir ve bu depoya dahil değildir.
