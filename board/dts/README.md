# Kart tanımı (device tree) — tek kaynak

T3 Gemstone O1 ana Linux'ta yok; kartın donanım tarifi burada duruyor. **Debian ve mainline
çekirdekleri aynı dosyalardan** derlenir, iki ayrı kopya yoktur.

| Dosya | İçerik | Kim kullanır |
|---|---|---|
| `k3-am67a-t3-gem-o1-common.dtsi` | Kartın görüntü dışındaki her şeyi: bellek, güç, SD/eMMC, Ethernet, Wi-Fi/BT, USB, PCIe, CAN, sensörler, LED'ler, fan, DSP'ler | ikisi |
| `k3-am67a-t3-gem-o1-pinmux.dtsi` | Pin ayarları (T3'ün dosyası) | ikisi |
| `k3-am67a-t3-gem-o1-display.dtsi` | Ekran birimi (DSS1) → SiI9022 HDMI köprüsü → HDMI soketi, HDMI ses (McASP1) | yalnız Debian (HDMI yamaları gerekir) |
| `k3-am67a-t3-gem-o1-gpu-v7.4.dtsi` | GPU ve VPU SRAM düğümleri (ana Linux 7.4'ten) | yalnız mainline (6.18 LTS; 7.4 ve sonrasına geçilirse silinir) |
| `k3-am67a-t3-gem-o1.dts` | common + display | `kernels/debian/build.sh` |
| `k3-am67a-t3-gem-o1-headless.dts` | common + gpu-v7.4 | `kernels/mainline/build.sh` |
| `k3-am67a-t3-gem-o1-lts-hdmi.dts` | common + display + gpu-v7.4 | `kernels/lts-hdmi/build.sh` (6.18 LTS + HDMI yamaları) |
| `build-dtb.sh` | Bir `.dts`'i çekirdek ağacının `.dtsi` dosyalarına karşı derler; ağaca hiçbir şey kopyalamaz | iki `build.sh` |

Çıktının adı her iki çekirdekte de `k3-am67a-t3-gem-o1.dtb` (U-Boot bu adı yükler).

**Değiştirmek:** dosyayı düzenleyin, sonra yalnızca DTB'yi yeniden üretin (saniyeler sürer,
çekirdek yeniden derlenmez):

```bash
DTB_ONLY=1 kernels/debian/build.sh      # → kernels/debian/out/k3-am67a-t3-gem-o1.dtb
DTB_ONLY=1 kernels/mainline/build.sh    # → kernels/mainline/out/k3-am67a-t3-gem-o1.dtb
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
