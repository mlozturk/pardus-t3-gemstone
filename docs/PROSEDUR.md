# T3 Gemstone O1 — Pardus 25 imajlarını yeniden üretme prosedürü

**Hedef kart:** T3 Gemstone O1 (TI AM67A / J722S, BeagleY-AI ile aynı işlemci)
**Derleme makinesi:** Pardus 25 x86_64 (Debian 13 tabanlı her dağıtım olur)
**Üretilen:** Pardus 25.2 "yirmibes" arm64 SD kart imajları
**Durum (22 Kasım 2026):** iki imaj da kernel.org **6.18 LTS** çekirdeğiyle kartta açılıyor:
masaüstü (`lite`, HDMI yamalarıyla) ve ekransız (`minimal`, yamasız). Özet: `docs/OZET.md`.

Bu belge "nasıl yapılır" kısmıdır. Gerekçeler ve yaşanan sorunlar `docs/BELGE.md`'de ("BELGE §n"),
çekirdek yamaları `docs/HDMI-YAMALARI.md`'de.

---

## 0. Kısaca

```bash
./build.sh desktop  --release 2026.11     # masaüstü: lite + 6.18 LTS + HDMI   → ~423 MB
./build.sh headless --release 2026.11     # ekransız: minimal + 6.18 LTS       → ~181 MB
sudo ./scripts/04-flash-sd.sh /dev/sdX release/2026.11/<imaj>.img.xz
```

`build.sh` §2–§5'teki adımları sırayla çalıştırır, sonucu zaten olanı atlar, yalnız §5 için `sudo`
ister. Çıktı: `out/` ve `release/2026.11/`. Adımlar aşağıda tek tek de anlatılıyor.

| Adım | Betik | İlk sefer (4 vCPU) | Sonra |
|---|---|---|---|
| Kaynaklar | `scripts/00-fetch-sources.sh` | ~20 dk (indirme) | atlanır |
| Bootloader | `scripts/01-bootloader.sh` | ~3 dk | atlanır |
| Çekirdek | `kernels/lts-hdmi/build.sh` / `kernels/mainline/build.sh` | ~11 / ~10 dk | atlanır; DTB her seferinde (saniyeler) |
| Sistem + imaj | `scripts/03-rootfs-image.sh` | ~60–75 dk | ~10–15 dk |
| Yayın klasörü | `scripts/06-release.sh` | saniyeler | — |

## 1. Derleme makinesi (bir kez)

Pardus 25 x86_64; 4 işlemci, 4–6 GB bellek (bilgisayarda gerçekten boş olandan fazla değil,
§8), 60 GB boş disk, internet.

```bash
sudo apt-get update
sudo apt-get install -y git make bison flex bc swig libssl-dev libgnutls28-dev uuid-dev \
  python3-setuptools python3-pyelftools python3-dev python3-cryptography python3-yaml \
  python3-jsonschema yamllint device-tree-compiler u-boot-tools \
  debootstrap qemu-user-static binfmt-support \
  libncurses-dev libelf-dev libdw-dev lz4 lzop kpartx parted dosfstools e2fsprogs btrfs-progs \
  rsync ccache kmod cpio xz-utils zstd fakeroot dpkg-dev debhelper wget
git clone <depo> gemstone && cd gemstone
```

Debian ve Pardus arşiv anahtarlarını `03` kendisi güncel paketten indirir (derleme makinesindeki eski olabilir).

**Sürümler:** projede sabitlenen her sürüm `versions.env`'dedir (derleyici, U-Boot, TF-A, OP-TEE,
TI firmware, Debian ve kernel.org çekirdekleri, indirilen dosyaların SHA-256'ları). Sürüm
değiştirmek için yalnızca bu dosya düzenlenir.

## 2. Kaynaklar — `scripts/00-fetch-sources.sh`

```bash
./scripts/00-fetch-sources.sh            # sonunda SOURCES_OK
```

kernel.org GCC 11.5.0 çapraz derleyicileri (`gcc-11.5.0-nolibc/`) ve `u-boot/`, `linux/` (T3),
`trusted-firmware-a/`, `optee_os/`, `ti-linux-firmware/` ağaçları `versions.env`'deki
**commit'lerle** indirilir; T3 Linux'a `patches/linux-0001…` uygulanır. Tekrar çalıştırmak güvenli.
6.18 ve Debian çekirdeklerinin kaynaklarını kendi betikleri indirir (§4).

## 3. Bootloader — `scripts/01-bootloader.sh`

```bash
./scripts/01-bootloader.sh 2>&1 | tee out-bootloader.log    # sonunda BOOTLOADER_OK
```

1. TF-A: `PLAT=k3 TARGET_BOARD=lite SPD=opteed` → `bl31.bin`
2. OP-TEE: `PLATFORM=k3-am62x CFG_ARM64_core=y` → `tee-pager_v2.bin`
3. R5 U-Boot: `am67a_t3_gem_o1_r5_defconfig` + `BINMAN_INDIRS=ti-linux-firmware` → `tiboot3.bin` (HS-FS)
4. A53 U-Boot: `am67a_t3_gem_o1_a53_defconfig` + `BL31` `TEE` → `tispl.bin`, `u-boot.img`

Çıktı `out/boot/`. Kartta 15 Kasım'dan beri bu dosyalarla açılıyor.

## 4. Çekirdek

### 4.1 Masaüstü: 6.18 LTS + HDMI — `kernels/lts-hdmi/build.sh` (~11 dk)

```bash
kernels/lts-hdmi/build.sh                 # sonunda LTS_HDMI_KERNEL_OK
DTB_ONLY=1 kernels/lts-hdmi/build.sh      # yalnız kart tanımı değiştiyse (saniyeler)
```

`kernels/mainline/build.sh`'i `VARIANT=hdmi` ile çalıştırır:

1. `kernels/mainline/linux-6.18.64.tar.xz` kernel.org'dan indirilir, SHA-256'sı denetlenir (iki
   çekirdek aynı arşivi kullanır).
2. `kernels/lts-hdmi/src` git deposu olarak açılır (etiket `v6.18.64`), `kernels/lts-hdmi/patches/`
   içindeki **20 HDMI yaması** `git am` ile uygulanır (`docs/HDMI-YAMALARI.md`). Sürüm ya da yama
   kümesi değişince kaynak kendiliğinden yeniden hazırlanır.
3. Ayar: `defconfig`, yalnız TI K3, kartın sürücüleri (BELGE §24.2), üstüne ekran birimi
   (`DRM_TIDSS`), HDMI köprüsü (`DRM_SII902X`), HDMI ses (McASP, simple-card, hdmi-codec),
   HDMI'da metin konsolu. Ayarın reddettiği seçenek olursa `WARNING` yazar.
4. `make bindeb-pkg` → `kernels/lts-hdmi/out/linux-image-6.18.64-gemstone-hdmi+_6.18.64-1gemstone1_arm64.deb`,
   `Image`, `release`; kart tanımı `board/dts/k3-am67a-t3-gem-o1-lts-hdmi.dts` →
   `k3-am67a-t3-gem-o1.dtb`.

### 4.2 Ekransız: 6.18 LTS yamasız — `kernels/mainline/build.sh` (~10 dk)

```bash
kernels/mainline/build.sh                 # sonunda MAINLINE_KERNEL_OK
DTB_ONLY=1 kernels/mainline/build.sh
```

Aynı arşiv, **yama yok**, ekran ve ses kapalı; kart tanımı
`board/dts/k3-am67a-t3-gem-o1-headless.dts`. Çıktı `kernels/mainline/out/`, sürüm
`6.18.64-gemstone-mainline`. Ayrıntı: BELGE §24.

### 4.3 7.3 kararlı: `kernels/stable-hdmi/build.sh` · `kernels/stable/build.sh` (~11 / ~10 dk)

```bash
kernels/stable-hdmi/build.sh              # sonunda STABLE_HDMI_KERNEL_OK
kernels/stable/build.sh                   # sonunda STABLE_PLAIN_KERNEL_OK
```

Aynı betik (`kernels/mainline/build.sh`), `TRACK=stable` ile: arşiv `linux-7.3.5.tar.xz`
(`versions.env` → `STABLE_*`), HDMI'lıda `kernels/stable-hdmi/patches/` içindeki **21 yama**
(`kernels/stable-hdmi/patches/README.md`), kart tanımları 6.18'dekilerle aynı. Sürüm adları
`7.3.5-gemstone-stable-hdmi+` / `7.3.5-gemstone-stable`. 7.3 LTS değil: 7.4 çıkınca birkaç hafta
içinde kapanır; o zaman `versions.env`'de `STABLE_*` 7.4.y'ye çekilir ve yamalar denenir.

### 4.4 Diğer çekirdekler (seçenek)

| Çekirdek | Betik | Not |
|---|---|---|
| Debian 7.2.12 + 24 yama | `kernels/debian/build.sh` (~60–90 dk) | 22 Kasım'a kadar masaüstü çekirdeği. Debian kaynak paketi `versions.env`'deki özetlerle indirilir (ana sunucuda yoksa `snapshot.debian.org`); BELGE §21 |
| T3 6.12.24 | `scripts/02-kernel.sh` (~45–60 dk) | Kart üreticisinin çekirdeği; overlay'leri (kamera, DSI) olan tek çekirdek |

### 4.5 Kart tanımı (device tree)

Tek kaynak `board/dts/` (`board/dts/README.md`): görüntü dışı her şey `-common.dtsi`, HDMI/ses
`-display.dtsi`, 7.4 öncesi çekirdekler için GPU `-gpu-v7.4.dtsi`. Değiştirince:
`DTB_ONLY=1 kernels/<ad>/build.sh`, sonra §7.2 ile karta ya da §5 ile yeni imaj.

## 5. Sistem + SD imajı — `scripts/03-rootfs-image.sh` (root gerekir)

```bash
./build.sh desktop                                    # = aşağıdaki, önceki adımlarla birlikte
sudo ./scripts/03-rootfs-image.sh --distro pardus --flavor lite --kernel lts-hdmi
sudo ./go-pardus --flavor minimal --kernel mainline   # aynı, günlük out-pardus.log
```

Sıra:

1. Saat kontrolü (depo sunucusunun saatiyle >5 dk fark varsa düzeltilir; apt imzaları için).
2. **debootstrap** (`yirmibes-deb`, trixie betiği) + qemu ile ikinci aşama. `.stage1-done` ile atlanır.
3. **Paketler** (chroot içinde): sistem araçları, boyuta göre paket listesi (`lite`: tek tek seçilmiş
   Pardus XFCE parçaları, önerilen paketler olmadan), Türkçe, bizim çekirdek `.deb`'i. Kullanıcı
   `pardus` / `temppwd`, ilk girişte şifre değişimi zorunlu. `.stage2-done` ile atlanır.
4. **2b:** çekirdek paketi değiştiyse kurulur; listede olup kurulu olmayan `lite` paketleri kurulur.
   Kurmadan önce paketin `release` dosyasıyla aynı derlemeden geldiği denetlenir.
5. **2c:** rootfs'te tek çekirdek kalır (diğerleri silinir); GPU ve C7x firmware'i; masaüstlülerde
   trixie-backports'tan Mesa 26 ve `20-gemstone-noglamor.conf` (`.gpu-1`).
   `lite`/`minimal`: belgeler, man sayfaları, fazla diller silinir (`.slim-1`); derleyici
   takımı kaldırılır (**her paket önce denenir, başka paket götürecekse bırakılır**; ör. `cpp` X
   araçları için kalır), yalnız kartın yüklediği 16 firmware dosyası kalır, initramfs yeniden
   üretilir (`.slim-2`). dpkg kuralları sonraki güncellemelerde de bunları dışarıda tutar.
6. **Ağ:** sabit IP `10.42.0.12/24`, ağ geçidi `10.42.0.1`, DNS `1.1.1.1`/`8.8.8.8`; `gemstone-beacon`
   5 sn'de bir `10.42.0.11`'e ping atar; `gemstone-growroot` ilk açılışta kök bölümü kartın tamamına
   büyütür. Çekirdek güncelleme betiği `/usr/local/sbin/gemstone-kernel-update` (şifresiz `sudo`
   kuralı imajda **yok**).
7. **BOOT dosyaları** (`build/bootfs/`): `tiboot3.bin`, `tispl.bin`, `u-boot.img` (`out/boot/`),
   çekirdeğin `Image` + `k3-am67a-t3-gem-o1.dtb`, initramfs (T3'ün dosya adıyla), `uEnv.txt`.
8. **İmaj:** MBR; p1 `BOOT` **FAT32 128 MiB, `mkfs.vfat -F 32 -s 1 -h 0 -g 16/32`** (T3 imajıyla
   birebir; başka biçimle ROM açmıyor, BELGE §12 #20); p2 `rootfs` btrfs (zstd). Derlemenin durum
   dosyaları imaja girmez; `/tmp` ve `/var/tmp` boşaltılır.
9. `xz` (`--xz N`, varsayılan 3, yayında 6) ve `.sha256` (yolsuz dosya adlarıyla). Çıktı:
   `out/t3-gem-o1-pardus-yirmibes-arm64-<boyut>-AAAAGGAA-own-k<çekirdek>.img(.xz)`; sonunda `IMAGE_OK`.

**Seçenekler** (`--help`; öncelik: komut satırı > ortam değişkeni > eski işaret dosyası > varsayılan):

| Seçenek | Değerler | İmaj adı |
|---|---|---|
| `--distro` | `pardus` (`build.sh`, `go-pardus`), `debian` (`03` tek başına, `go`) | `-pardus-yirmibes-` / `-debian-trixie-` |
| `--flavor` | `lite` (varsayılan), `minimal`, `full` | `-lite-`, `-minimal-`, `-full-` |
| `--kernel` | `lts-hdmi` (varsayılan), `mainline`, `stable-hdmi`, `stable`, `debian`, `t3` | `-klts-hdmi`, `-kmainline`, `-kstable-hdmi`, `-kstable`, `-kdebian`, (ek yok) |
| `--vendor-bl`, `--vendor-initrd` | karşılaştırma için T3'ün bootloader'ı / initramfs'i (`vendor-boot/` gerekir) | `-vbl`, `-vinitrd`, `-vboot` |
| `--xz N` | 0–9 | — |

Ortam değişkenleri (sudo'suz çağrıda): `IMG_SIZE`, `NET_IP`, `NET_GW`, `NET_PC`, `NET_DNS`,
`EXTRA_PKGS`, `FIX_CLOCK=0`. Hangi değişiklikte hangi dosyaya dokunulacağı: BELGE §16.3.

**T3 dosyalarıyla karşılaştırma (isteğe bağlı):** T3'ün resmi imajının BOOT bölümünden
`tiboot3.bin tispl.bin u-boot.img gemstone-image-rd-t3-gem-o1.cpio.gz` dosyaları `vendor-boot/`'a
kopyalanır (`config.ini` kopyalanmaz: Wi-Fi ve şifre özetleri içerir).

## 6. SD karta yazma ve yayın

### 6.1 Karta yazma — `scripts/04-flash-sd.sh`

1. Kart okuyucuyu derleme makinesine takın (sanal makine kullanıyorsanız okuyucuyu VM'e yönlendirin).
2. ```bash
   lsblk -o NAME,SIZE,TRAN,MODEL                       # okuyucu: ör. sdb, TRAN=usb
   sudo ./scripts/04-flash-sd.sh /dev/sdb lite          # adında "lite" geçen en yeni imaj
   sudo ./scripts/04-flash-sd.sh /dev/sdb release/2026.11/<imaj>.img.xz --no-verify
   ```
   İmaj adı yerine yol (`.img` ya da `.img.xz`; `.xz` açılmadan yazılır) ya da hiçbir şey (en yeni)
   verilebilir. Yazmadan önce `.sha256` ile denetlenir, sonra geri okunup karşılaştırılır
   (`--no-verify` atlar). Yalnız USB/MMC ve ≤256 GB diskler kabul edilir; kök diske asla yazmaz.
   Sonunda `FLASH_OK`.
3. Kartı okuyucudan çıkarıp board'a takın.

Alternatif: `.img.xz` balenaEtcher ya da Raspberry Pi Imager ile de doğrudan yazılabilir.

### 6.2 Yayın klasörü — `scripts/06-release.sh`

```bash
scripts/06-release.sh 2026.11             # en yeni masaüstü (lts-hdmi) + ekransız (mainline) imaj
./build.sh headless --kernel stable      --release 2026.11-7.3   # 7.3.5 yayını, iki imaj
./build.sh desktop  --kernel stable-hdmi --release 2026.11-7.3
```

`release/2026.11/`: imajlar (`out/`'a sabit bağlantı, ek yer tutmaz), `.sha256`'lar, `SHA256SUMS`,
`SURUM-NOTLARI.md` ve `BUILDINFO.txt`. `./build.sh … --release 2026.11` bunu kendisi çalıştırır.
Belgeleri güncelledikten ve git'e kaydettikten sonra yeniden çalıştırmak `BUILDINFO`'daki commit'i
ve sürüm notunu tazeler.

## 7. Kartta

### 7.1 İlk açılış ve denetim

1. Açılış anahtarları SD konumunda. HDMI (masaüstü) ve Ethernet bağlı; bilgisayarın Ethernet adresi
   `10.42.0.11/24`.
2. Güç verin. Seri konsol yoksa Wireshark'ta `arp or icmp`:

| Görülen | Anlamı |
|---|---|
| `Who has 10.42.0.11? Tell 10.42.0.12` | U-Boot `uEnv.txt`'yi okudu |
| `Who has 10.42.0.99?` | `booti` başarısız (çekirdek/DTB/initramfs yüklenemedi) |
| 5 sn'de bir ping | Pardus açıldı |
| Hiçbir şey | ROM `tiboot3.bin`'i okuyamadı: anahtar, FAT biçimi, kart |

3. Giriş `pardus` / `temppwd` (yeni şifre istenir); ağdan `ssh pardus@10.42.0.12`.
4. Denetim:

```bash
uname -r                                    # 6.18.64-gemstone-hdmi+ / 6.18.64-gemstone-mainline
systemd-analyze; free -h
lsmod | grep -E 'tidss|sii902x|powervr|rtw88|m_can'
cat /sys/class/remoteproc/*/state           # C7x: running
dmesg --level=err,warn | head -40           # beklenenler: BELGE §24.5 tablosu
aplay -l; speaker-test -c 2 -t sine -f 440 -l 1      # masaüstü, hoparlörlü HDMI ekranda
```

### 7.2 Çekirdeği SSH ile güncelleme — `scripts/05-kernel-deploy.sh`

Bir kez, derleme makinesinde: `ssh-keygen -t ed25519 -f ~/.ssh/gemstone_board` ve
`ssh-copy-id -i ~/.ssh/gemstone_board.pub pardus@10.42.0.12`.

Bir kez, her yeni kartta (güncelleme betiği imajda hazır; şifresiz kural root'a eşdeğer olduğu
için imaja konmaz, BELGE §22.8):

```bash
echo 'pardus ALL=(root) NOPASSWD: /usr/local/sbin/gemstone-kernel-update, /usr/sbin/reboot' | sudo tee /etc/sudoers.d/gemstone-kernel-update
sudo chmod 440 /etc/sudoers.d/gemstone-kernel-update
```

Her yeni çekirdekte:

```bash
KERNEL=lts-hdmi scripts/05-kernel-deploy.sh 10.42.0.12     # masaüstü kartı
KERNEL=mainline scripts/05-kernel-deploy.sh 10.42.0.12     # ekransız kart
KERNEL=stable-hdmi scripts/05-kernel-deploy.sh 10.42.0.12  # 7.3.5 (ya da stable)
```

Kartta: eski `Image`, initramfs, DTB `/var/backups/gemstone-boot/`'a yedeklenir; paket kurulur;
`vmlinuz` gzip ise açılıp ham `Image` yazılır (`ARMd` imzası denetlenir, BELGE §22.5.1); BOOT'ta yer
denetlenir; yeniden başlatılır; dmesg `kernels/<ad>/dmesg-<tarih>.txt`'ye kaydedilir.
Geri alma: kartta `sudo gemstone-kernel-update --restore && sudo reboot`.

**Yalnız DTB'yi denemek** (kart okuyucuda): BOOT bölümündeki `k3-am67a-t3-gem-o1.dtb` yedeklenip
yenisi kopyalanır (`kernels/<ad>/out/`'tan). Geri dönüş: yedeği eski adıyla geri koymak.

### 7.3 Yeni bir 6.18.y'ye geçmek

1. `versions.env`: `MAINLINE_VERSION=6.18.<yeni>`, `MAINLINE_SHA256=` (cdn.kernel.org
   `v6.x/sha256sums.asc` içindeki `linux-6.18.<yeni>.tar.xz` satırı), `MAINLINE_PKGVER`.
2. `./build.sh desktop --rebuild-kernel` ve `./build.sh headless --rebuild-kernel`. HDMI yamaları
   uymazsa derleme `git am`'de durur: `docs/HDMI-YAMALARI.md` §5.
3. Karta §7.2 ile ya da yeni imajla.

## 8. Derleme makinesi notları

1. **Bellek:** Derleme makinesine yeterli boş RAM ayrılmalı; sanal makinede host'ta gerçekten boş
   olandan fazlası verilmez. Az bellek + ağır derleme (çekirdek ve debootstrap aynı anda) kararsızlık
   yaratabilir. 4 GB / 4 vCPU ile derlemeler sorunsuz.
2. **Sanallaştırma:** Sanal makinede tam donanım sanallaştırması (VT-x/AMD-V) açık olmalı; aksi halde
   çok vCPU'lu derlemede kararsızlık görülebilir.
3. **Saat:** Derleme makinesinin saati geride olabilir; `03` saati depo sunucusunun saatiyle
   karşılaştırıp 5 dakikadan fazla sapma varsa düzeltir (apt imzaları için).
4. **Çökmeden sonra:** çekirdek derleme klasöründe boş (0 bayt) `.o` dosyaları kalabilir:
   `find kernels/<ad>/build -name '*.o' -size 0 -delete`. Yarım açılmış kaynağı ve yarım rootfs'i
   betikler kendileri tanıyıp yeniden kurar.
5. **Şifresiz sudo (otomasyon için, geçici):** `/etc/sudoers.d/gemstone-build` yalnız `go`,
   `go-pardus`, `03`, `04` için. İş bitince: `sudo rm /etc/sudoers.d/gemstone-build`.

## 9. Sorun giderme

| Belirti | Neden / çözüm |
|---|---|
| Kart hiç açılmıyor (ARP yok) | BOOT FAT düzeni ve `uEnv.txt` (BELGE §12 #19, #20) |
| `Who has 10.42.0.99?` | `booti` hatası: `Image` sıkıştırılmış mı (BELGE §22.5.1), DTB ya da initramfs adı |
| Çekirdek açılıyor, kök bulunamıyor | `root=/dev/mmcblk${mmcdev}p2 rootfstype=btrfs`; çekirdekte `BTRFS_FS=y`, `MMC_SDHCI_AM654=y` |
| Giriş ekranında `FileNotFoundError: 'xset'` | `x11-xserver-utils` eksik; eski `03`'ün temizliği `cpp` ile birlikte silmişti (22 Kasım'da düzeltildi). `./build.sh desktop` eksik paketleri geri kurar |
| HDMI sesi yavaş ve kalın | Kart tanımında `auxclk-fs-ratio` kalmış; gerçek saat `system-clock-frequency = <96000000>` (HDMI-YAMALARI §3) |
| dmesg'de sürekli "stream has more channels … mcasp (0)", ASoC -22 | `playback-only` `cpu` ve `codec` düğümlerinde de olmalı (6.18'in ayrıştırıcısı) |
| "HDMI: Unknown ELD version 0" | Ekran HDMI üzerinden ses desteği bildirmiyor (hoparlörsüz monitör); hata değil |
| Vulkan "permission denied" | Kullanıcı `render` grubunda değil (BELGE §23.2) |
| Mesa 26 sonrası masaüstü yavaş/bozuk | `20-gemstone-noglamor.conf` (BELGE §23.3) |
| dmesg: `j722s-c71_0-fw` yüklenemedi | C7x firmware bağları; `03` "2c" (BELGE §23.4) |
| Çekirdek derlemesinde anlamsız bağlama hatası (ör. `put_unaligned_le64`) | Kaynak yarım açılmış (VM çöktü): `rm -rf kernels/<ad>/src`, yeniden çalıştırın |
| `git am` HDMI yamasında duruyor | Yeni 6.18.y'de kod yeri değişmiş: HDMI-YAMALARI §5 |
| `03`: "kernel mismatch" | `out/` içindeki paket ile `release` farklı derlemelerden: çekirdeği yeniden derleyin |
| apt: imza `Not live until …` | Saat geride; `03` düzeltir (BELGE §12 #13) |
| Pardus: `xfce4 : Depends: xfdesktop4 …` | `xfdesktop4-data` sabitlemesi (BELGE §12 #17) |
| `05-kernel-deploy`: "No space left" | BOOT dolu; eski `.prev` yedekleri (BELGE §22.5) |
| Kart güncellemeden sonra U-Boot'ta kalıyor | BOOT'a sıkıştırılmış çekirdek yazılmış; betiğin yeni sürümü açıyor (BELGE §22.5.1) |
