# T3 Gemstone O1 için Pardus 25: sürüm notları (7.3 çekirdekli)

**Sürüm:** 2026.11-7.3 · **Tarih:** 22 Kasım 2026

Ana yayın **2026.11** ile aynı sistem (Pardus 25.2, aynı bootloader, aynı kart tanımı, aynı paket
seçimi); yalnız çekirdek farklı: kernel.org'un güncel kararlı sürümü **7.3.5**. 7.3 **LTS değil**:
7.4 çıktıktan birkaç hafta sonra güncelleme almayı bırakır. Uzun süre kullanılacak kartlar için
ana yayın (6.18 LTS, destek Aralık 2028'e kadar) önerilir; bu yayın daha yeni çekirdeği denemek
isteyenler için.

## İmajlar

| | Masaüstü | Ekransız |
|---|---|---|
| Dosya | `t3-gem-o1-pardus-yirmibes-arm64-lite-20261122-own-kstable-hdmi.img.xz` | `t3-gem-o1-pardus-yirmibes-arm64-minimal-20261122-own-kstable.img.xz` |
| Boyut | 426 MB (açılınca 8 GB) | 180 MB (açılınca 4 GB) |
| Kimin için | HDMI ekranla, Pardus XFCE masaüstü | SSH ile kullanılacak kart |
| Çekirdek | `7.3.5-gemstone-stable-hdmi+`: kernel.org 7.3.5 + HDMI yamaları (7.3'e taşınmış 21 yama) | `7.3.5-gemstone-stable`: kernel.org 7.3.5, **yamasız** |
| SD kart | en az 8 GB (16 GB+ önerilir) | en az 4 GB |

**SHA-256** (`sha256sum -c SHA256SUMS`):

```
c23a5d20b58cf00c469d222a58e2460e42d0ddd64dd89ee9507bd00bd1302c29  t3-gem-o1-pardus-yirmibes-arm64-lite-20261122-own-kstable-hdmi.img.xz
730825bafb02ca95a9a000d8dcc46615f0b44d5bf6c8c4dfcc3fc3cd737caedc  t3-gem-o1-pardus-yirmibes-arm64-minimal-20261122-own-kstable.img.xz
```

## Kurulum

Ana yayınla aynı: `.img.xz` balenaEtcher ya da Raspberry Pi Imager ile SD karta yazılır; açılış
anahtarları SD konumunda; giriş **`pardus`** / **`temppwd`** (ilk girişte yeni şifre istenir);
bilgisayarın Ethernet adresi `10.42.0.11/24` yapılıp `ssh pardus@10.42.0.12`.

## Durum

İki imaj derlendi ve denetlendi (22 Kasım): BOOT bölümünde 7.3.5 çekirdeği (ham `Image`, `ARMd` imzası) ve kart tanımı, masaüstü paketinde `tidss`, `sii902x`, `display-connector`, McASP ve `hdmi-codec` ses modülleri ile `powervr`; kart tanımında AM62P ekran birimi, HDMI köprüsü, ses kartı, GPU, `rgmii-rxid`. **Kartta henüz açılmadı.**

Kart tanımının kaynağı ve paketler ana yayında kartta denenmiş olanlarla aynıdır (DTB'nin işlemci
ortak dosyalarından gelen kısmı 7.3'ünkü) (HDMI görüntü ve ses, GPU,
C7x, Ethernet, Wi-Fi: ana yayının sürüm notu). Fark yalnız çekirdekte: 7.3'te HDMI ses ayrıştırıcısının
`playback-only` hatası zaten düzeltilmiş, DSS sürücüsü 7.2'ye daha yakın.

## Çekirdek güncellemeleri

7.3.y düzeltme sürümleri çıktıkça: derleme makinesinde `versions.env`'deki `STABLE_VERSION`,
`STABLE_SHA256`, `STABLE_PKGVER` değiştirilir, `./build.sh desktop --kernel stable-hdmi
--rebuild-kernel` / `./build.sh headless --kernel stable --rebuild-kernel`, çalışan karta
`KERNEL=stable-hdmi` ya da `KERNEL=stable` ile `scripts/05-kernel-deploy.sh <kart-ip>`. 7.3 kapanınca
iki yol var: ana yayının 6.18 LTS çekirdeğine geçmek (`KERNEL=lts-hdmi` / `mainline`, aynı betikle)
ya da `STABLE_*`'ı 7.4.y'ye çekip yamaları denemek (7.4'te GPU düğümü işlemci tarifinde zaten var).

## Bilinen sorunlar ve güvenlik

Ana yayınla aynı (ekran karardıktan sonra görüntü, masaüstü işlemciyle çiziliyor, HDMI ses 44,1 kHz
ailesi, kamera/DSI eklentisi yok, varsayılan şifre değiştirilmeli, imajlarda şifresiz `sudo` yok).

## Kaynaklar ve yeniden üretme

```bash
./build.sh headless --kernel stable      --release 2026.11-7.3
./build.sh desktop  --kernel stable-hdmi --release 2026.11-7.3
```

| Parça | Sürüm |
|---|---|
| Çekirdek (iki imaj) | kernel.org `7.3.5`, paket `7.3.5-1gemstone1` |
| HDMI yamaları (masaüstü) | Tomi Valkeinen'in tidss/AM62P serisi, 7.3'e taşınmış 21 yama (`kernels/stable-hdmi/patches/`, `docs/HDMI-YAMALARI.md` §6) |
| Bootloader, firmware, kart tanımı, Pardus, Mesa | ana yayınla aynı (`BUILDINFO.txt`) |
