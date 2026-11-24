# HDMI yamaları: Debian 7.2.12, 6.18 LTS ve 7.3

Kartın HDMI'ı işlemcinin (TI AM67A / J722S) görüntü birimine (DSS) bağlı. Bu birimin sürücü
desteği ana Linux'a **henüz girmedi**; TI'dan Tomi Valkeinen'in yama serileriyle geliyor. Biz bu
yamaları iki farklı çekirdeğe uyguladık:

| | Debian çekirdeği (eski masaüstü) | 6.18 LTS + HDMI (şimdiki masaüstü) |
|---|---|---|
| Klasör | `kernels/debian/` | `kernels/lts-hdmi/` (derleme betiği `kernels/mainline/build.sh`, `VARIANT=hdmi`) |
| Kaynak | Debian `linux 7.2.12-1~bpo13+1` (trixie-backports), Debian'ın kendi yamalarıyla | kernel.org `linux-6.18.64.tar.xz`, başka yama yok |
| Bizim eklediğimiz yama | 24: 22 HDMI + 2 GPU/VPU (ana Linux 7.4'ten) | 20 HDMI |
| GPU/VPU-SRAM düğümleri | yama 0023–0024 (işlemci tarifine) | `board/dts/k3-am67a-t3-gem-o1-gpu-v7.4.dtsi` (kart tarafında) |
| Kart tanımı | `board/dts/k3-am67a-t3-gem-o1.dts` | `board/dts/k3-am67a-t3-gem-o1-lts-hdmi.dts` (aynı ortak + ekran dosyaları) |
| Ayar | Debian'ın tam arm64 ayarı + ekler (§21.3) | arm64 `defconfig`, yalnız TI K3 + kartın sürücüleri + ekran/ses (§24.2, §27.3) |
| Çekirdek sürümü | `7.2.12-gemstone+` | `6.18.64-gemstone-hdmi+` |
| Boyut (`Image` / modül / initramfs) | 52 MB / 4241 / 37 MB | 26 MB / 732 / 15 MB |
| Destek | kernel.org'da 7.2 kapandı (7.2.15 EOL) | 6.18 LTS, **Aralık 2028'e kadar** |
| Kartta | ✅ 17–18 Kasım | ✅ 22 Kasım: HDMI görüntü, masaüstü, GPU; ses sürücüsü hatasız |

(§ numaraları `docs/BELGE.md`'ye göredir.)

## 1. Seriler ve kaynakları

| Seri | Yamalar | Posta listesi |
|---|---|---|
| Tomi Valkeinen, *arm64: ti: Use syscon for the main conf* (Mayıs 2026) | 6 | <https://lore.kernel.org/all/20260528-ti-main-conf-v1-0-a54ac5c8d081@ideasonboard.com/> |
| Tomi Valkeinen, *drm/tidss: Add BeagleY-AI display support (and some more)* **v3** (29 Mayıs 2026) | 15 (+1 parça) | <https://lore.kernel.org/all/20260529-beagley-ai-display-v3-0-7fefdc5d1adf@ideasonboard.com/> |

Ana Linux'taki durum (22 Kasım 2026): bu yamalar **kabul edilmedi**. 3 Eylül 2026'da 10 yamalık bir
"hazırlık" serisi gönderilip "kuyruğa alındı" denildi; hangi ağaca alındığı yazılmadı. Asıl HDMI
yamaları bekliyor. Gönderildikleri yer: DRM için `drm-misc-next`, kart tarifleri için TI'ın
`ti-k3-dts-next` (ana Linux'un geliştirme dalı; LTS değil). İçlerindeki yazarlar: Tomi Valkeinen,
Swamil Jain (AM62P ekran birimi), Jayesh Choudhary (işlemci tarifine ekran birimi), Andrew Davis
(BeagleY-AI HDMI).

## 2. Yama yama: 7.2 serisi → 6.18 serisi

"Debian" sütunu `kernels/debian/patches/`, "6.18" sütunu `kernels/lts-hdmi/patches/` numarasıdır.

| Debian | 6.18 | Konu | 6.18'de |
|---|---|---|---|
| 0001 | 0001 | dts: j784s4/j742s2 `pcieN-ctrl` düğüm adları | olduğu gibi |
| 0002 | 0002 | dts: k3-am62*: `clock-controller` → `clock` | **uyarlandı** (a) |
| 0003 | — | dts: k3-am62-main: `oldi-io-controller` → `dss-oldi-io-ctrl` | **atlandı** (b) |
| 0004–0005 | 0003–0004 | bindings: `ti,j721e-system-controller` gevşetme + yeni uyumlular | olduğu gibi |
| 0006 | 0005 | dts: "main conf" bölgesi `syscon` + `simple-mfd` | olduğu gibi |
| 0007–0011 | 0006–0010 | bindings: DSS (AM62L'nin ayrılması, sadeleştirme, OLDI güç alanı, `ti,dpi-io-ctrl`, AM62P DSS) | olduğu gibi |
| 0012 | — | tidss: fazladan `pm_runtime_mark_last_busy` kaldırma | **atlandı** (c) |
| 0013 | 0011 | tidss/oldi: kullanılmayan `OLDI_LB_CTRL` tanımı | olduğu gibi |
| 0014 | 0012 | tidss: DPI çıkışını algılama | olduğu gibi |
| 0015 | 0013 | tidss: DPI veri/senkron kenar ayarı (`ti,dpi-io-ctrl`) | **uyarlandı** (d) |
| 0016 | 0014 | tidss: `DPIENABLE` biti | **uyarlandı** (d) |
| 0017 | 0015 | tidss/oldi: OLDI sinyal kutupları (v3 11/15'in uyan parçası) | olduğu gibi |
| 0018 | 0016 | tidss/oldi: OLDI'yi yardımcı (aux) sürücüye çevirme | olduğu gibi |
| 0019 | 0017 | tidss: AM62P ekran birimi desteği (`ti,am62p-dss`) | olduğu gibi |
| 0020 | 0018 | dts: k3-am62p-j722s-common-main: ekran birimi düğümleri | **uyarlandı** (e) |
| 0021 | 0019 | dts: BeagleY-AI HDMI görüntü ve ses | olduğu gibi |
| 0022 | 0020 | tidss/oldi: OLDI kutupları (v3 11/15'in kalan parçası, `atomic_check`) | **uyarlandı** (f) |
| 0023 | — | dts: GPU düğümü (ana Linux 7.4, `9c8d40bf`) | kart tarafında: `gpu-v7.4.dtsi` |
| 0024 | — | dts: VPU'ya SRAM (ana Linux 7.4, `330236fd`) | kart tarafında: `gpu-v7.4.dtsi` |

v3 serisinin 11. yaması (OLDI kutupları) 7.2.12'ye de tek parça uymamıştı; o zaman iki parçaya
bölündü (0017 + 0022). 6.18'de aynı bölünme korundu.

### Uyarlamalar ve atlananlar

Hiçbirinde yeni kod yazılmadı; 6.18 ile 7.2 arasında yeri değişen kod, yamanın 6.18'deki
karşılığına kondu. Her biri `git am` uygulamasında reddedilen parçaya (hunk) bakılarak yapıldı.

| | Yama | 7.2'de | 6.18'de | Ne yapıldı |
|---|---|---|---|---|
| (a) | 0002 | AM62P'nin `audio_refclk0/1` düğümleri ortak dosyada (`k3-am62p-j722s-common-main.dtsi`) | aynı düğümler `k3-am62p-main.dtsi`'de; J722S'inkiler (`k3-j722s-main.dtsi`) zaten `clock@` adlı | Ad değişikliği `k3-am62p-main.dtsi`'ye yapıldı. Bizim işlemcimiz (J722S) için değişiklik yok |
| (b) | 0003 | AM62'de `dss_oldi_io_ctrl: oldi-io-controller@8600` var | bu düğüm 6.18'in AM62 dosyasında hiç yok | Atlandı. Yalnız AM62'yi ilgilendiriyor (bizim işlemcimiz değil); sonraki yamalar ona dayanmıyor |
| (c) | 0012 | `pm_runtime_put_autosuspend()` "son kullanım" zamanını kendisi işaretliyor; ayrı çağrı fazla | 6.18'de bu işaretleme fonksiyonun içinde olmayabilir | Atlandı. Çağrıyı yerinde bırakmak zararsız (en kötü ihtimalle iki kez işaretlenir), kaldırmak güç yönetimini bozabilir |
| (d) | 0015, 0016 | Görüntü çıkışının kutup/zamanlama ayarı `dispc_vp_prepare()` içinde | aynı ayarlar `dispc_vp_enable()` içinde (7.x'te prepare'a taşınmış) | İki ekleme (DPI saat yönü yazımı, `DPIENABLE` biti) `dispc_vp_enable()` içine, `DISPC_VP_SIZE_SCREEN` yazımından sonra ve birim açılmadan (`ENABLE` biti) önce kondu: 7.2'deki sırayla aynı |
| (e) | 0020 | `dss_oldi_io_ctrl` düğümü `main_conf` içinde `audio_refclk` düğümlerinin yanına ekleniyor | 6.18'in ortak dosyasında `audio_refclk` düğümleri yok (bkz. a) | Düğüm `main_conf` bölgesinin başına (`phy_gmii_sel`'den önce) eklendi; adres ve içerik aynı |
| (f) | 0022 | `tidss_oldi_atomic_check()` `pre_enable`'ın önüne; `pre_enable` imzası `struct drm_atomic_commit *` | imza `struct drm_atomic_state *` (7.x'te ad değişmiş) | Fonksiyon aynı içerikle `tidss_oldi_atomic_pre_enable()`'ın önüne eklendi; işlev tablosuna `.atomic_check` kaydı yamanın uyan kısmından geldi |

**Temizlik (22 Kasım):** Her iki seride OLDI kutup yamasının ilk parçası (Debian 0017 / 6.18
0015) bir `tidss_oldi.c.rej` dosyası (reddedilmiş parça kaydı) ekliyor, ikinci parçası (0022 /
0020) onu siliyordu. Son ağaçta yoktu ama yamalarda gereksizdi; çıkarıldı. Ardından iki seri temiz
kaynağa baştan uygulandı: 6.18 serisi çekirdeğin derlendiği ağacın **dosya dosya aynısını**,
Debian serisi kart tanımı dosyaları (`board/dts/`'ye taşınan 3 dosya) dışında aynısını verdi.

## 3. Kart tanımında ses düzeltmeleri (iki çekirdek için)

HDMI ses kartı tanımı `board/dts/k3-am67a-t3-gem-o1-display.dtsi`'de; iki çekirdek de kullanır.
6.18 denemesinde iki sorun bulundu (BELGE §27.4) ve kart tanımında düzeltildi:

| Sorun | Neden | Düzeltme |
|---|---|---|
| Ses ~%8 yavaş ve kalın (Debian çekirdeğinde de vardı: "Sample-rate is off by … PPM") | `&mcasp1 { auxclk-fs-ratio = <2177>; }` (T3 ve BeagleY-AI'den gelen): sürücüye "AUXCLK = 2177 × örnekleme hızı" diyor. Gerçek AUXCLK sabit 96 MHz; oran yalnız 44,1 kHz'te doğru. PipeWire'ın 48 kHz'inde sürücü 104,5 MHz sanıp yanlış bölen seçiyordu | Oran kaldırıldı; ses kartının işlemci (`cpu`) düğümüne `system-clock-frequency = <96000000>`. Sürücü her hızın gerçek hatasını hesaplayıp yalnız 44,1 kHz ailesini sunuyor; PipeWire dönüştürüyor. Kartta: "off by 400 PPM" (%0,04) |
| "stream has more channels (2) than are enabled in mcasp (0)", ASoC error -22 (sürekli) | Ses sunucusu HDMI'dan kayıt açmayı deniyor; McASP1'de giriş hattı yok. Kart düzeyindeki `playback-only` 6.18'de etkisiz: `graph_util_parse_link_direction()` bayrağı kart, `cpu` ve `codec` düğümünden sırayla okuyup **her seferinde üstüne yazıyor** (7.x'te "yalnız varsa yaz" diye düzeltilmiş) | `playback-only` `cpu` ve `codec` düğümlerine de eklendi. İki çekirdekte de aynı sonucu verir |

## 4. Ayar (config) farkı

| | Debian | 6.18 + HDMI |
|---|---|---|
| Başlangıç | Debian'ın arm64 ayarı (`linux-base-7.2.12+deb13-arm64` paketinden) | `make defconfig` |
| Diğer işlemci aileleri | açık (Debian her kartı destekler) | kapalı (yalnız `ARCH_K3`) |
| Ekran / HDMI / ses | `DRM_TIDSS`, `DRM_SII902X`, McASP, simple-card, hdmi-codec: modül | aynısı, modül (§27.3) |
| GPU | `DRM_POWERVR` (Debian'da kapalıydı, açtık) | `DRM_POWERVR` |
| Modül imzası | açık, anahtar derlemede üretilir | kapalı (`defconfig` gibi; imzasız modül çekirdeği "kirli" işaretlemez çünkü imza denetimi de kapalı) |
| SA2UL kripto hızlandırıcı | kapalı (7.2'de kendi testlerinde çöküyordu, §21.3) | açık (modül, `defconfig`'teki gibi); 6.18 denemelerinin dmesg uyarılarında hatası görülmedi |
| Hata ayıklama bilgisi | kapalı | kapalı |

Ses ayarları iki çekirdekte aynı çıktı (`SND_SOC_DAVINCI_MCASP`, `SND_SOC_TI_*_PCM`,
`SND_SIMPLE_CARD`, `SND_SOC_HDMI_CODEC`, `TI_SYSCON_CLK`, `TI_K3_UDMA`); ses sorunlarının ikisi de
ayardan değil, kart tanımından ve 6.18'deki ayrıştırıcıdan geliyordu.

## 5. Yeni bir 6.18.y'ye geçerken

LTS serisine yalnızca hata düzeltmeleri girer; ekran sürücüsü (`drivers/gpu/drm/tidss/`) genelde
değişmez, yamalar uymaya devam eder. `versions.env`'de sürüm değişince `kernels/lts-hdmi/build.sh`
kaynağı yeniden açıp 20 yamayı uygular; uymayan olursa `git am` orada durur. O zaman:

```bash
cd kernels/lts-hdmi/src          # yarım kalmış git am
git am --show-current-patch=diff  # uymayan parça
# kodu elle yerleştir, sonra:
git add -A && git am --continue
git format-patch --filename-max-length=40 --zero-commit -o ../patches v6.18.<yeni>..HEAD
```

## 6. 7.3 serisi (ikinci yayın, `kernels/stable-hdmi/`)

Aynı yamalar kernel.org **7.3.5**'e de taşındı (`kernels/stable-hdmi/patches/`, 21 yama; derleme
`kernels/mainline/build.sh`, `TRACK=stable VARIANT=hdmi`). 7.3, 7.2'ye çok yakın olduğu için
6.18'deki uyarlamaların (0002, 0015, 0016, 0020, 0022) hiçbiri gerekmedi; Debian serisiyle farkı:

| Debian | 7.3 | Durum |
|---|---|---|
| 0001–0013 | 0001–0013 | olduğu gibi (0012 `pm_runtime_mark_last_busy` silme dahil: 7.3'te de geçerli) |
| 0014 | 0014 | **uyarlandı:** `tidss_kms.c`'deki köprü arama bloğu 7.3'te değişmiş; `dpi_output` ataması `dev_err_probe` bloğundan sonra, `if (panel) {` satırından önce |
| 0015–0020 | 0015–0020 | olduğu gibi |
| 0021 | — | **atlandı:** BeagleY-AI kart tarifi; kısmen 7.3'te var, bizim kartımız değil |
| 0022 | 0021 | olduğu gibi |
| 0023–0024 | — | GPU/VPU-SRAM, 6.18'deki gibi `board/dts/k3-am67a-t3-gem-o1-gpu-v7.4.dtsi`'den |

Kart tanımı 6.18 HDMI çekirdeğininkiyle aynı dosya (`-lts-hdmi.dts`), ayar da aynı (`defconfig` +
TI K3 + ekran/ses). Sürüm adı `7.3.5-gemstone-stable-hdmi+`. 7.3 LTS olmadığından 7.4 çıktıktan
birkaç hafta sonra kapanır; uzun süreli kurulum için 6.18 LTS önerilir.

## 7. Ana Linux'a girince

Yamalar kabul edilip bir ana Linux sürümüne girdiğinde (ve o sürüm bir LTS olduğunda) `lts-hdmi`
gereksizleşir: masaüstü de yamasız `mainline` çekirdeğiyle çalışır, yalnızca kart tanımında ekran
dosyası (`-display.dtsi`) eklenir. Takip: <https://lore.kernel.org/dri-devel/?q=am62p+dss>.
