# Debian kernel'ine eklediğimiz yamalar

`build.sh` bu klasördeki yamaları sırayla (`git am`) Debian'ın `linux 7.2.12-1~bpo13+1`
kaynağının üstüne uygular. Toplam 24 yama var; hiçbiri bizim yazdığımız kod değil.

| Yama | Ne yapıyor | Kaynak |
|---|---|---|
| 0001–0006 | "main conf" bölgesini syscon olarak tanımlar (HDMI yamalarının ön şartı) | Tomi Valkeinen, *arm64: ti: Use syscon for the main conf*, 6 yama, Mayıs 2026 |
| 0007–0021 | AM62P/J722S ekran birimi (DSS) desteği ve HDMI | Tomi Valkeinen, *drm/tidss: Add BeagleY-AI display support* v3, 15 yama, Mayıs 2026 |
| 0017 + 0022 | v3'ün 11. yaması (OLDI sinyal kutupları); 7.2.12'ye tutmayan bir parçası elle uyarlandı | aynı seri |
| 0023 | GPU düğümü (PowerVR BXS-4-64) | ana Linux v7.4, commit `9c8d40bf` (Michael Walle / TI) |
| 0024 | Video çözücüye (VPU) çip içi SRAM | ana Linux v7.4, commit `330236fd` (Brandon Brnich / TI) |

**Kart tanımı (DTS) yama değil:** `board/dts/` klasöründe duruyor ve
Debian ile mainline çekirdekleri aynı dosyalardan derleniyor (`board/dts/README.md`). Önceden
0023–0025 numaralı yamalardı (kart tanımı, `rgmii-id` + R5 kapalı, HDMI sesi yalnızca çalma); git
geçmişinde duruyorlar. Daha önce hazırlanmış bir `kernels/debian/src` ağacında bu eski yamalar hâlâ
uygulanmış olarak durur; zararı yok, DTB artık oradan değil `board/dts/`'den üretilir.

Posta listesi bağlantıları:

- <https://lore.kernel.org/all/20260528-ti-main-conf-v1-0-a54ac5c8d081@ideasonboard.com/>
- <https://lore.kernel.org/all/20260529-beagley-ai-display-v3-0-7fefdc5d1adf@ideasonboard.com/>

Bu yamalar ana Linux'a (mainline) girdiğinde ve Debian o sürüme geçtiğinde 0001–0022 gereksiz
olur; 0023–0024 Debian 7.4'e geçince gereksiz olur.

Yeni yama eklemek: `kernels/debian/src` içinde değişikliği commit'leyin, sonra

```bash
cd kernels/debian/src
git format-patch --filename-max-length=40 -o ../patches -1
```

ve dosyayı sıradaki numarayla adlandırın. Dosya adları kısa tutulur (bazı dosya sistemlerinde çok
uzun yollar sorun çıkarabilir).
