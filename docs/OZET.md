# T3 Gemstone O1 için Pardus 25 — özet (22 Kasım 2026)

Bu sayfa projenin kısa özetidir: elimizde ne var, ne yaptık, nasıl yeniden üretiriz. Ayrıntılar:
`docs/BELGE.md` (gerekçeler, sorunlar, ölçümler), `docs/PROSEDUR.md` (adım adım),
`docs/HDMI-YAMALARI.md` (çekirdek yamaları), `docs/SURUM-NOTLARI.md` (dağıtılacak sürüm notu).

## 1. Elimizde ne var

**İki yayın imajı** (`release/2026.11/`, SD karta doğrudan yazılır; ARM kartlarda ISO olmaz):

| İmaj | Ne | Çekirdek | Boyut | Kartta |
|---|---|---|---|---|
| `…-lite-20261122-own-klts-hdmi.img.xz` | Masaüstü: sade Pardus XFCE, HDMI, GPU (Vulkan) | 6.18 LTS + HDMI yamaları | 423 MB | ✅ HDMI görüntü, masaüstü; ses sürücüsü hatasız |
| `…-minimal-20261122-own-kmainline.img.xz` | Ekransız: SSH, ağ, kart araçları, Python 3 | 6.18 LTS, **yamasız** | 181 MB | ✅ 15 s açılış, 298 MB bellek, GPU, C7x |

Yanlarında `SHA256SUMS`, sürüm notu ve `BUILDINFO.txt` (derlendiği git commit'i, sabit sürümler).
İkisinde de: Pardus 25.2, Türkçe, kullanıcı `pardus` / `temppwd` (ilk girişte değişir), sabit IP
`10.42.0.12`, ilk açılışta kartın tamamına genişleme, çekirdek güncelleme betiği hazır.

**Açılış zincirinin her parçası bizim derlememiz:** bootloader (TF-A, OP-TEE, U-Boot), çekirdek,
initramfs, Pardus kurulumu. Kart üreticisinin (T3) hazır sistemine bağlı değil; kapalı olan
yalnızca TI'ın güvenlik/güç firmware'leri (kaynak kodu yayımlanmıyor).

**Çekirdek seçenekleri** (`--kernel`):

| Ad | Ne | Kullanım |
|---|---|---|
| `lts-hdmi` | kernel.org 6.18 LTS + 20 HDMI yaması | masaüstü (varsayılan) |
| `mainline` | kernel.org 6.18 LTS, yamasız | ekransız |
| `stable-hdmi` | kernel.org 7.3.5 + 21 HDMI yaması | 7.3 yayınının masaüstü imajı |
| `stable` | kernel.org 7.3.5, yamasız | 7.3 yayınının ekransız imajı |
| `debian` | Debian 7.2.12 + 24 yama | eski masaüstü çekirdeği; seçenek olarak duruyor |
| `t3` | T3'ün 6.12'si | karşılaştırma için |

İki 6.18 çekirdeği aynı kaynaktan gelir ve **Aralık 2028'e kadar** güncellenebilir (kernel.org LTS).
7.3 çekirdekleri daha yeni ama LTS değil: 7.4 çıktıktan birkaç hafta sonra kapanır. Onlarla ikinci
bir yayın var: `release/2026.11-7.3/` (aynı Pardus, aynı kart tanımı, yalnız çekirdek farklı).

**Depo** (`~/gemstone`, git):

| Ne | Nerede |
|---|---|
| Tek komut | `build.sh` |
| Sabit sürümler (hepsi) | `versions.env` |
| Adım betikleri | `scripts/00`–`06` |
| Kart tanımı (tek kaynak) | `board/dts/` |
| Çekirdekler | `kernels/lts-hdmi/`, `kernels/stable-hdmi/` (yamalar), `kernels/mainline/` (ortak derleme betiği), `kernels/stable/`, `kernels/debian/` |
| Kartta çalışan güncelleme betiği | `board/gemstone-kernel-update` |
| Belgeler | `README.md`, `docs/` |

## 2. Ne yaptık (kronoloji)

| Tarih | İş |
|---|---|
| 5–8 Kas | Derleme ortamı; bootloader ve T3 çekirdeği kaynaktan. Pardus 25 imajı açılmadı → neden: BOOT bölümünün FAT düzeni ve `uEnv.txt` (BELGE §12 #19, #20) |
| 15 Kas | Kendi bootloader'ımız ve initramfs'imizle açılış; ilk açılışta genişleme. Sade masaüstü (`lite`) |
| 16–17 Kas | Debian'ın hazır çekirdeğinde HDMI yok (§20) → Debian kaynağı + posta listesindeki HDMI yamaları; dmesg temizliği; SSH ile çekirdek güncelleme |
| 18 Kas | GPU (PowerVR, Mesa 26, Vulkan) ve C7x DSP'ler; masaüstü yavaşlığı (glamor) çözüldü |
| 21 Kas | Yamasız mainline çekirdek ve masaüstüsüz `minimal` sistem |
| 22 Kas | Betiklerin düzenlenmesi: tek komut, tek kart tanımı, tek sürüm dosyası, yayın betiği; eski imajlar temizlendi (21 GB) |
| 22 Kas | Ekransız çekirdek uzun destekli 6.18 LTS'e geçti (kartta açıldı) |
| 22 Kas | HDMI yamaları 6.18'e taşındı; masaüstü de 6.18 LTS'te (kartta HDMI çalıştı) |
| 22 Kas | İmajlardan derleyici ve kullanılmayan firmware çıkarıldı (masaüstü 617 → 423 MB); HDMI ses saati ve `playback-only` düzeltildi |
| 22 Kas | İkinci yayın: 7.3.5 çekirdekli masaüstü ve ekransız imaj (HDMI yamaları 7.3'e taşındı, 21 yama) |

## 3. Nasıl yeniden üretilir

Pardus 25'te (4 işlemci, 4–6 GB bellek, 60 GB disk), normal kullanıcıyla:

```bash
# bir kez: paketler (README §1) ve depo
git clone <depo> gemstone && cd gemstone

./build.sh desktop  --release 2026.11     # masaüstü imajı
./build.sh headless --release 2026.11     # ekransız imaj
sudo ./scripts/04-flash-sd.sh /dev/sdX release/2026.11/<imaj>.img.xz
```

`build.sh` kaynakları indirir (sürümler `versions.env`'de sabit, özetleri denetlenir), bootloader'ı,
çekirdeği ve imajı derler; yalnız imaj adımı `sudo` ister. İlk sefer ~2 saat, sonra ~15 dakika.
Adım adım: `docs/PROSEDUR.md`.

**Yeniden üretilebilirlik denetimi (22 Kasım):** HDMI yama serisi temiz bir 6.18.64 kaynağına
baştan uygulandı; çekirdeğin derlendiği ağacın dosya dosya aynısını verdi. Debian serisi de temiz
7.2.12 kaynağına uygulandı. İki kart tanımı (DTB) yeni tek kaynaktan üretilip eskileriyle
karşılaştırıldı: içerik aynı. Paketler Pardus/Debian depolarından geldiği için aynı gün olmayan bir
derlemede paket sürümleri (güvenlik güncellemeleri) farklı olabilir; çekirdek, bootloader ve kart
tanımı birebir aynı çıkar.

## 4. Açık konular

| Konu | Durum |
|---|---|
| HDMI sesi kulakla | Sürücü hatasız, 44,1 kHz; hoparlörlü ekranda dinlenmedi |
| Ekran karardıktan sonra görüntünün geri gelmemesi | Debian çekirdeğinde görüldü; 6.18'de denenmedi |
| Ethernet `rgmii-id` ayarı | Sürücü öneriyor, denenmedi (çalışan: `rgmii-rxid`) |
| HDMI yamalarının ana Linux'a girmesi | Bekleniyor; girince masaüstü de yamasız çekirdeğe geçer |
| Kamera / DSI ekran eklentileri | Yeni çekirdeklerde yok |
| `apt upgrade` ile çekirdek güncelleme | Kendi apt depomuz gerekli; kurulmadı (şimdilik SSH ile `05`) |
| C7x'te gerçek yapay zekâ firmware'i | Şu an TI'ın deneme firmware'i |
| Masaüstüne tarayıcı | Bilerek yok (`lite`); istenirse `firefox-esr` |

Geliştirme makinesindeki şifresiz `sudo` kuralı (`/etc/sudoers.d/gemstone-build`) iş bitince
kaldırılmalı: `sudo rm /etc/sudoers.d/gemstone-build`. Kartlardaki kural ise yalnız elle eklenir
(BELGE §22.8).
