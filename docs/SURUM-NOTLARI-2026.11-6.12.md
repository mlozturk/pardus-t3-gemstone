# T3 Gemstone O1 için Pardus 25: sürüm notları (Debian trixie 6.12 çekirdekli)

**Sürüm:** 2026.11-6.12 · **Tarih:** 25 Kasım 2026

Ana yayın **2026.11** ile aynı sistem (Pardus 25.2, aynı bootloader, aynı kart tanımı, aynı paket
seçimi); yalnız çekirdek farklı: **Pardus 25 / Debian 13 trixie'nin kendi çekirdeği 6.12.118**
(Debian'ın kaynak paketi `linux 6.12.118-1` ve Debian'ın ayarı). Debian güvenlik ekibi trixie'nin
ömrü boyunca bu çekirdeğe güncelleme çıkarır. Sistemle aynı çekirdek ailesini isteyenler için.

## İmajlar

| | Masaüstü | Ekransız |
|---|---|---|
| Dosya | `t3-gem-o1-pardus-yirmibes-arm64-lite-20261125-own-ktrixie-hdmi.img.xz` | `t3-gem-o1-pardus-yirmibes-arm64-minimal-20261125-own-ktrixie.img.xz` |
| Boyut | 534 MB (açılınca 8 GB) | 278 MB (açılınca 4 GB) |
| Kimin için | HDMI ekranla, Pardus XFCE masaüstü | SSH ile kullanılacak kart |
| Çekirdek | `6.12.118-gemstone-trixie-hdmi+`: Debian 6.12.118 + 6.18'den ekran ve GPU sürücüleri + HDMI yamaları (14 yama) | `6.12.118-gemstone-trixie+`: Debian 6.12.118, yalnız kartın parçaları ek |
| SD kart | en az 8 GB (16 GB+ önerilir) | en az 4 GB |

İmajlar ana yayından büyük: Debian'ın ayarı bütün arm64 donanımları için ~4.400 modül içeriyor
(6.18'de ~800). Kartta yalnız gerekenler yüklenir. Masaüstü imajı kartta denendi; ekransız imaj
derlendi ve denetlendi, kartta henüz açılmadı. Dosyalar hızlı `xz -3` sıkıştırmayla üretildi;
yeniden derlenmedi.

**SHA-256** (`sha256sum -c SHA256SUMS`):

```
4cb75c3a71956bbccd58de0a1988366edf15a5b13b40cf97ade2ac2f9cf81670  t3-gem-o1-pardus-yirmibes-arm64-lite-20261125-own-ktrixie-hdmi.img.xz
349200ff8d524ccef8e031bac04f1ad96c4550876ea6a21d656b1b2555e4f99a  t3-gem-o1-pardus-yirmibes-arm64-minimal-20261125-own-ktrixie.img.xz
```

## Kurulum

Ana yayınla aynı: `.img.xz` balenaEtcher ya da Raspberry Pi Imager ile SD karta yazılır; açılış
anahtarları SD konumunda; giriş **`pardus`** / **`temppwd`** (ilk girişte yeni şifre istenir);
bilgisayarın Ethernet adresi `10.42.0.11/24` yapılıp `ssh pardus@10.42.0.12`.

## Durum

- **Masaüstü:** kartta açıldı, HDMI'dan masaüstü geldi; ilk denemede sorunsuz (25 Kasım).
  GPU (Vulkan) ve HDMI sesi ayrıca ölçülmedi.
- **Ekransız:** derlendi ve denetlendi (pakette Ethernet, K3 RTC, güç düğmesi); **kartta henüz
  açılmadı.**

6.12'de bu kartın ekran birimi ve GPU'su için sürücü yok. Masaüstü çekirdeğinde bu iki sürücü
6.18.64'ten olduğu gibi alındı, HDMI yamaları üstüne uygulandı ve 6.12'nin arayüzlerine uyarlandı
(~70 satır; `kernels/trixie-hdmi/patches/README.md`). Uyarlama ana Linux'ta değil, bu projede.

## Çekirdek güncellemeleri

Debian yeni bir 6.12 güvenlik sürümü çıkardığında: derleme makinesinde `versions.env`'deki
`TRIXIE_*` (sürüm ve dört dosyanın özetleri) değiştirilir, `./build.sh desktop --kernel
trixie-hdmi --rebuild-kernel` / `./build.sh headless --kernel trixie --rebuild-kernel`, çalışan
karta `KERNEL=trixie-hdmi` ya da `KERNEL=trixie` ile `scripts/05-kernel-deploy.sh <kart-ip>`.
Ana yayının 6.18 LTS çekirdeğine geçmek de aynı betikle olur (`KERNEL=lts-hdmi` / `mainline`).

## Bilinen sorunlar ve güvenlik

Ana yayınla aynı (ekran karardıktan sonra görüntü, masaüstü işlemciyle çiziliyor, HDMI ses 44,1 kHz
ailesi, kamera/DSI eklentisi yok, varsayılan şifre değiştirilmeli, imajlarda şifresiz `sudo` yok).

## Kaynaklar ve yeniden üretme

```bash
./build.sh headless --kernel trixie
./build.sh desktop  --kernel trixie-hdmi
scripts/06-release.sh 2026.11-6.12 out/*-lite-*-ktrixie-hdmi.img.xz out/*-minimal-*-ktrixie.img.xz
```

| Parça | Sürüm |
|---|---|
| Çekirdek (iki imaj) | Debian `linux 6.12.118-1` (trixie-security), paket `6.12.118-1gemstone1` |
| Ekran/GPU sürücüleri ve HDMI yamaları (masaüstü) | v6.18.64'ten `tidss` ve `imagination` + Tomi Valkeinen'in serisinden 12 yama + 6.12 uyarlaması (`kernels/trixie-hdmi/patches/`, `docs/HDMI-YAMALARI.md` §7) |
| Bootloader, firmware, kart tanımı, Pardus, Mesa | ana yayınla aynı (`BUILDINFO.txt`) |
