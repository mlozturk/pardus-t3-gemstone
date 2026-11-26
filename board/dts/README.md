# Kart tanımı (device tree) — tek kaynak

T3 Gemstone O1 ana Linux'ta yok; kartın donanım tarifi burada duruyor. **Bütün çekirdekler aynı
dosyalardan** derlenir, ayrı kopyalar yoktur.

| Dosya | İçerik | Kim kullanır |
|---|---|---|
| `k3-am67a-t3-gem-o1-common.dtsi` | Kartın görüntü dışındaki her şeyi: bellek, güç, SD/eMMC, Ethernet, Wi-Fi/BT, USB, PCIe, CAN, sensörler, LED'ler, fan, DSP'ler | üç DTS tarifi |
| `k3-am67a-t3-gem-o1-pinmux.dtsi` | Pin ayarları (T3'ün dosyası) | üç DTS tarifi (`common` dahil eder) |
| `k3-am67a-t3-gem-o1-display.dtsi` | Ekran birimi (DSS1) → SiI9022 HDMI köprüsü → HDMI soketi, HDMI ses (McASP1) | Debian tarifi ve HDMI'lı tarifler (`lts-hdmi`, `stable-hdmi`, `trixie-hdmi`). HDMI yamaları gerekir |
| `k3-am67a-t3-gem-o1-gpu-v7.4.dtsi` | GPU ve VPU SRAM düğümleri (ana Linux 7.4'ten; 7.4'ten önceki çekirdekte yok) | headless ve HDMI'lı tarifler. Çekirdek 7.4 ve sonrasına geçince silinir. Debian 7.2'de bu düğümler yamadadır, bu dosya yok |
| `k3-am67a-t3-gem-o1.dts` | common + display | `kernels/debian/build.sh` |
| `k3-am67a-t3-gem-o1-headless.dts` | common + gpu-v7.4 | `kernels/mainline/build.sh`, `kernels/stable/build.sh`, `kernels/trixie/build.sh` |
| `k3-am67a-t3-gem-o1-lts-hdmi.dts` | common + display + gpu-v7.4 | `kernels/lts-hdmi/build.sh`, `kernels/stable-hdmi/build.sh`, `kernels/trixie-hdmi/build.sh` |
| `build-dtb.sh` | Bir `.dts`'i çekirdek ağacının `.dtsi` dosyalarına karşı derler; ağaca hiçbir şey kopyalamaz | `kernels/*/build.sh` |

Çıktının adı hepsinde `k3-am67a-t3-gem-o1.dtb` (U-Boot bu adı yükler).

**Değiştirmek:** dosyayı düzenleyin, sonra yalnızca DTB'yi yeniden üretin (saniyeler sürer,
çekirdek yeniden derlenmez). Çıktı `kernels/<ad>/out/k3-am67a-t3-gem-o1.dtb`:

```bash
DTB_ONLY=1 kernels/debian/build.sh
DTB_ONLY=1 kernels/mainline/build.sh       # stable aynı headless tarif
DTB_ONLY=1 kernels/lts-hdmi/build.sh       # stable-hdmi aynı HDMI tarif
DTB_ONLY=1 kernels/trixie/build.sh         # ekransız
DTB_ONLY=1 kernels/trixie-hdmi/build.sh    # masaüstü
```

Karta göndermek için `scripts/05-kernel-deploy.sh` (çekirdek paketiyle birlikte gider).

**Ethernet ayarı:** `phy-mode = "rgmii-rxid"` kartta çalışan değerdir. Sürücü `rgmii-id` öneriyor
(docs/BELGE.md §21.7); denenmedi. Yanlış değer kartı ağdan koparır, değiştirmeden önce seri konsol
hazır olsun.

**Geçmiş:** Önceden Debian için kart tanımı yama olarak (0023–0025), mainline için
`kernels/mainline/dts/` altında ayrı bir kopya olarak duruyordu. Debian çıktısındaki DTB de elle
`rgmii-rxid` yapılmıştı; yani `build.sh` kartta çalışan DTB'yi kendisi üretmiyordu. Birleştirmede
iki DTB'nin yeni kaynaktan üretilen halleri eskileriyle karşılaştırıldı: düğüm ve özellikler aynı,
yalnızca phandle numaraları (düğüm sırası) ve T3'ün `base_dtb_timestamp` alanı farklı.
