# 7.3 kararlı + HDMI: yamalar

`kernels/stable-hdmi/build.sh` bu klasördeki 21 yamayı kernel.org'un **7.3** kaynağına
(`versions.env` → `STABLE_VERSION`) `git am` ile uygular. Yamalar, Debian 7.2.12 çekirdeğinde
kullandığımız HDMI serisinin (Tomi Valkeinen, `kernels/debian/patches/0001–0022`) 7.3'e taşınmış
halidir. 7.3, 7.2'ye çok yakın olduğu için 6.18'deki uyarlamaların neredeyse hiçbiri
gerekmedi.

| Burada | Debian serisinde | Durum |
|---|---|---|
| 0001–0013 | 0001–0013 | olduğu gibi |
| 0014 | 0014 | **uyarlandı:** `tidss_kms.c`'de 7.3'te köprü arama bloğu değişmiş; `dpi_output` ataması (`bridge` varsa `!tidss_is_bridge_internal()`, yoksa `true`) `dev_err_probe` bloğundan sonra, `if (panel) {` satırından önce eklendi |
| 0015–0020 | 0015–0020 | olduğu gibi |
| — | 0021 | **atlandı:** BeagleY-AI kart tarifi; bir kısmı 7.3'te zaten var ve bizim kartımız değil |
| 0021 | 0022 | olduğu gibi (OLDI sinyal düzeltmesi) |

GPU ve VPU-SRAM düğümleri yama değil: kart tarifi `board/dts/k3-am67a-t3-gem-o1-lts-hdmi.dts`
(6.18 HDMI çekirdeğiyle aynı dosya) bunları `k3-am67a-t3-gem-o1-gpu-v7.4.dtsi`'den alır.
Ses düzeltmeleri (`system-clock-frequency`, `playback-only`) de aynı kart tarifinde.

**Not:** 7.3 LTS değil; 7.4 çıktıktan birkaç hafta sonra güncelleme almayı bırakır. Uzun süre
kalacak kurulumlar için `lts-hdmi` (6.18, Aralık 2028'e kadar) önerilir.

**Yeniden üretmek / değiştirmek:** hazırlanmış ağaç `kernels/stable-hdmi/src` bir git deposudur
(`git log v7.3.5..HEAD`). Değişiklik orada commit'lenir, sonra:

```bash
cd kernels/stable-hdmi/src
git format-patch --filename-max-length=40 --zero-commit -o ../patches v7.3.5..HEAD
```
