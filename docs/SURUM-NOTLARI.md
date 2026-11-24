# T3 Gemstone O1 için Pardus 25: sürüm notları

**Sürüm:** 2026.11 (ilk yayın) · **Tarih:** 22 Kasım 2026

T3 Gemstone O1 kartı (TI AM67A) için **her parçası kaynak koddan derlenmiş**, resmî olmayan bir
Pardus 25 sistemi: bootloader (TF-A, OP-TEE, U-Boot), Linux çekirdeği, initramfs ve Pardus
kurulumu. Kart üreticisinin (T3) hazır sistemine bağlı değildir. İki imajın çekirdeği de
kernel.org'un uzun destekli **6.18 LTS** sürümü (destek Aralık 2028'e kadar). Aynı sistemin
7.3.5 çekirdekli (LTS olmayan) bir eşi de var: yayın 2026.11-7.3.

## İmajlar

| | Masaüstü | Ekransız |
|---|---|---|
| Dosya | `t3-gem-o1-pardus-yirmibes-arm64-lite-20261122-own-klts-hdmi.img.xz` | `t3-gem-o1-pardus-yirmibes-arm64-minimal-20261122-own-kmainline.img.xz` |
| Boyut | 423 MB (açılınca 8 GB) | 181 MB (açılınca 4 GB) |
| Kimin için | HDMI ekranla, Pardus XFCE masaüstü | SSH ile kullanılacak kart: sunucu, sensör, yapay zekâ çalıştırıcı |
| Sistem | Pardus 25.2, sade XFCE (788 paket) | Pardus 25.2, masaüstü yok (285 paket) |
| Çekirdek | `6.18.64-gemstone-hdmi+`: kernel.org 6.18 LTS + HDMI yamaları (ana Linux'a henüz girmemiş ekran sürücüsü, 6.18'e taşındı) | `6.18.64-gemstone-mainline`: kernel.org 6.18 LTS, **yamasız** |
| SD kart | en az 8 GB (16 GB+ önerilir) | en az 4 GB |

**SHA-256** (yayın klasöründeki `SHA256SUMS` ve her imajın `.sha256` dosyasında da var;
`sha256sum -c SHA256SUMS`):

```
22fab4278e389e9285e2e377e0cda6bed51e17690af18b37815fbdc5e7ac2ed8  t3-gem-o1-pardus-yirmibes-arm64-lite-20261122-own-klts-hdmi.img.xz
fb13963e6d1e8bc85ff4aa25e18a0d1dd59ad6fdfdb0b41759b0ca402ba7040e  t3-gem-o1-pardus-yirmibes-arm64-minimal-20261122-own-kmainline.img.xz
```

## Kurulum

1. Dosyanın özetini denetleyin: Linux'ta `sha256sum -c <dosya>.img.sha256`, Windows'ta
   `Get-FileHash <dosya>.img.xz -Algorithm SHA256`.
2. `.img.xz` dosyasını balenaEtcher ya da Raspberry Pi Imager ile SD karta yazın (açmanıza gerek yok).
3. Kartın açılış anahtarları SD konumunda olsun. Ethernet'i bağlayın (masaüstü imajında HDMI da),
   güç verin.
4. Giriş: kullanıcı **`pardus`**, şifre **`temppwd`**. İlk girişte yeni şifre istenir.
5. Ağdan bağlanmak için bilgisayarın Ethernet adresini `10.42.0.11/24` yapın:
   `ssh pardus@10.42.0.12`.

İlk açılışta sistem kendini SD kartın tamamına genişletir ve her kart kendi SSH anahtarını üretir.

## Neler çalışıyor (kartta denendi, 22 Kasım)

| | Masaüstü | Ekransız |
|---|---|---|
| HDMI görüntü, Pardus giriş ekranı ve XFCE masaüstü | ✅ | ❌ (ekran yok) |
| HDMI ses | ✅ sürücü hatasız açılıyor, 44,1 kHz; hoparlörlü ekranda henüz dinlenmedi | ❌ |
| Ethernet, Wi-Fi, Bluetooth, USB, PCIe/NVMe, eMMC, CAN | ✅ (sürücüler yükleniyor; ayrıntılı test Debian çekirdeğiyle yapılmıştı) | ✅ ağ (SSH) çalışıyor; Wi-Fi/BT/CAN sürücüleri yüklü |
| GPU (PowerVR BXS-4-64), Vulkan | ✅ Mesa 26.1.6 | ✅ sürücü ve firmware çalışıyor; Vulkan için Mesa bu imajda yok |
| C7x yapay zekâ DSP'leri (2 adet) | ✅ TI deneme firmware'i | ✅ ikisi de çalışıyor |
| Pardus depolarından güncelleme (`apt`, Pardus Güncelleyici) | ✅ | ✅ (`apt`) |
| Açılış süresi / boşta bellek | ölçülmedi | **15,0 s / 298 MB** |

## Çekirdek güncellemeleri

İki çekirdek de aynı kernel.org 6.18 LTS kaynağından gelir; kernel.org 6.18 serisine **Aralık
2028'e kadar** düzeltme sürümleri çıkarır. Yeni bir 6.18.y için derleme makinesinde
`versions.env`'deki sürüm ve özet değiştirilir, `./build.sh desktop --rebuild-kernel` /
`./build.sh headless --rebuild-kernel`, çalışan karta
`KERNEL=lts-hdmi` (masaüstü) ya da `KERNEL=mainline` (ekransız) ile `scripts/05-kernel-deploy.sh <kart-ip>`.

Çekirdek `apt upgrade` ile gelmez (kendi derlememiz; apt deposu henüz yok). Kartın güncelleme
betiği (`/usr/local/sbin/gemstone-kernel-update`) imajda hazır. Yeni yazılmış bir kartta
`05-kernel-deploy.sh`'den önce bir kez SSH anahtarı ve sınırlı şifresiz `sudo` izni eklenir
(`docs/BELGE.md` §22.3); bu izin root'a eşdeğer olduğu için imaja konmaz.

## Bilinen sorunlar

- **Ekran karardıktan sonra görüntü geri gelmiyor** (masaüstü; Debian çekirdeğinde görüldü, 6.18'de
  denenmedi). Geçici çözüm: Ayarlar → Güç Yöneticisi → Ekran: karartmayı ve "Ekran güç
  yönetimi"ni kapatın.
- Masaüstü GPU ile değil işlemciyle çiziliyor. Bilerek böyle: GPU'yla çizim (glamor/zink) bu
  GPU'da henüz yavaş ve hatalı. GPU, Vulkan uygulamalarına açık.
- HDMI ses 44,1 kHz ve katlarında çalışır (ses birimi saatinin sınırı); 48 kHz'lik sesleri ses
  sunucusu (PipeWire) kendisi dönüştürür. Hoparlörsüz monitörlerde dmesg'de "HDMI: Unknown ELD
  version 0" yazar: monitör ses desteği bildirmiyor demektir, hata değildir.
- Kamera ve DSI ekran eklentileri (overlay) bu çekirdeklerde yok.
- Ekransız imajda ekran yok; kart yalnız ağdan (SSH) ya da seri konsoldan (UART, 115200 baud)
  kullanılır.
- Çekirdek Pardus/Debian deposundan güncellenmez (kendi derlememiz); yukarıdaki "Çekirdek
  güncellemeleri".
- Pardus, ARM için resmî destek vermiyor; bu imaj Pardus'un arm64 depolarıyla kurulmuş, resmî
  olmayan bir türevdir.

## Güvenlik

- Varsayılan şifre herkesçe biliniyor ve SSH şifreyle girişe açık: kart başka bir ağa bağlanmadan
  önce ilk giriş yapılıp şifre değiştirilmeli.
- İmajlarda şifresiz `sudo` kuralı **yok**.

## Kaynaklar ve yeniden üretme

Betikler, yamalar ve ayrıntılı belge depoda: `README.md`, `docs/BELGE.md` (§25 yayın imajları,
§27 6.18 LTS + HDMI, §24 yamasız çekirdek, §23 GPU, §26 betikler), `docs/PROSEDUR.md`. Aynı
imajları üretmek: `./build.sh desktop --release 2026.11` ve `./build.sh headless --release
2026.11`. Derlemenin git commit'i ve bütün sabit sürümler yayın klasöründeki `BUILDINFO.txt`'de.

| Parça | Sürüm |
|---|---|
| U-Boot | `t3gemstone/u-boot` `b8410d78120e` |
| TF-A / OP-TEE | `lts-v2.12.4` / `4.6.0` |
| TI firmware | `ti-linux-firmware` `11.01.03` |
| Çekirdek (iki imaj) | kernel.org `6.18.64` (LTS), paket `6.18.64-1gemstone1` |
| HDMI yamaları (masaüstü) | Tomi Valkeinen'in tidss/AM62P serisi, 6.18'e taşınmış 20 yama (`kernels/lts-hdmi/patches/`) |
| Kart tanımı | `board/dts/` (iki çekirdek için ortak) |
| Pardus | 25.2 "yirmibes", `depo.pardus.org.tr` |
| Mesa (masaüstü) | 26.1.6, Debian trixie-backports |
