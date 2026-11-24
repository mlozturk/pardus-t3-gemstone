# 6.18 LTS + HDMI: yamalar

`kernels/lts-hdmi/build.sh` bu klasördeki 20 yamayı kernel.org'un **6.18 LTS** kaynağına
(`versions.env` → `MAINLINE_VERSION`) `git am` ile uygular. Yamalar, Debian 7.2.12 çekirdeğinde
kullandığımız HDMI serisinin (Tomi Valkeinen, `kernels/debian/patches/0001–0022`) 6.18'e taşınmış
halidir. Hiçbiri bizim yazdığımız yeni kod değil; uyarlananlarda yalnızca kodun
6.18'deki yeri değişti.

| Burada | Debian serisinde | Durum |
|---|---|---|
| 0001 | 0001 | olduğu gibi |
| 0002 | 0002 | **uyarlandı:** 6.18'de AM62P'nin `audio_refclk` düğümleri `k3-am62p-main.dtsi`'de (7.2'de ortak dosyada); ad değişikliği oraya yapıldı. J722S'te zaten `clock@` adlı |
| — | 0003 | **atlandı:** yalnız AM62'yi ilgilendiriyor; değiştirdiği `oldi-io-controller` düğümü 6.18'de yok |
| 0003–0010 | 0004–0011 | olduğu gibi |
| — | 0012 | **atlandı:** `pm_runtime_mark_last_busy` çağrısını siler, çünkü 7.x'te `pm_runtime_put_autosuspend` bunu kendisi yapıyor. 6.18'de çağrıyı tutmak güvenli taraf |
| 0011–0012 | 0013–0014 | olduğu gibi |
| 0013 | 0015 | **uyarlandı:** DPI saat/senkron kenar ayarı. 6.18'de kutup ayarları `dispc_vp_enable()` içinde (7.2'de `dispc_vp_prepare()`'e taşınmış); ekleme oraya, `DISPC_VP_SIZE_SCREEN` yazımından sonra, birim açılmadan önce yapıldı |
| 0014 | 0016 | **uyarlandı:** `DPIENABLE` biti; aynı nedenle `dispc_vp_enable()` içinde, birim açılmadan hemen önce |
| 0015–0017 | 0017–0019 | olduğu gibi (asıl AM62P ekran birimi desteği dahil) |
| 0018 | 0020 | **uyarlandı:** işlemci tarifine ekran birimi. `dss_oldi_io_ctrl` düğümü 6.18'in `main_conf` bölgesine eklendi (7.2'de `audio_refclk` düğümlerinin yanında) |
| 0019 | 0021 | olduğu gibi |
| 0020 | 0022 | **uyarlandı:** OLDI `atomic_check` işlevi; 6.18'de `pre_enable` imzası `drm_atomic_state` kullanıyor, işlev onun önüne eklendi |

Ayrıntılı karşılaştırma (her uyarlamanın 7.2'deki ve 6.18'deki yeri, ses düzeltmeleri, ayar farkı):
`docs/HDMI-YAMALARI.md`. 0015 ve 0020'deki gereksiz `tidss_oldi.c.rej` dosyası
çıkarıldı; seri temiz 6.18.64'e uygulanınca derlenen ağacın aynısını veriyor.

GPU ve VPU-SRAM düğümleri yama değil: kart tarifi `board/dts/k3-am67a-t3-gem-o1-lts-hdmi.dts`
bunları `k3-am67a-t3-gem-o1-gpu-v7.4.dtsi`'den alır (Debian serisindeki 0023–0024'ün karşılığı).

**Yeniden üretmek / değiştirmek:** hazırlanmış ağaç `kernels/lts-hdmi/src` bir git deposudur
(`git log v6.18.64..HEAD`). Değişiklik orada commit'lenir, sonra:

```bash
cd kernels/lts-hdmi/src
git format-patch --filename-max-length=40 --zero-commit -o ../patches v6.18.64..HEAD
```

Yama kümesi değişince `build.sh` kaynağı kendiliğinden yeniden açıp yamalar (damga dosyası yama
özetini içerir). Yeni bir 6.18.y'ye geçerken (`versions.env`) yamalar genelde değişmeden uyar;
uymazsa `git am` orada durur.
