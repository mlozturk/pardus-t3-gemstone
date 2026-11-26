# Debian trixie 6.12 + HDMI/GPU: yamalar

`kernels/trixie-hdmi/build.sh` bu klasördeki 14 yamayı Debian'ın trixie çekirdek kaynağına
(`linux 6.12.118-1`, Debian'ın kendi yamaları uygulanmış; `versions.env` → `TRIXIE_KERNEL_*`)
`git am` ile uygular (24 Kasım 2026).

6.12'de AM62P/J722S DSS ve PowerVR BXS-4-64 için sürücü desteği yok. Bu yüzden önce iki sürücü
6.18'den alınıyor, HDMI serisi onların üstüne uygulanıyor, en son 6.12'nin çekirdek arayüzlerine
uyarlanıyor:

| Yama | Ne | Kaynak |
|---|---|---|
| 0001 | `drivers/gpu/drm/tidss` (ekran) ve `drivers/gpu/drm/imagination` (GPU) sürücüleri ile `include/uapi/drm/pvr_drm.h`, kernel.org **v6.18.64**'ten değiştirilmeden | kernel.org |
| 0002–0013 | 6.18 serisinden alınan 12 yama: HDMI yamaları ve bu karta gereken DTS/binding bağımlılıkları (`lts-hdmi` 0001, 0005, 0009, 0011–0018, 0020), olduğu gibi | Tomi Valkeinen'in serisi |
| 0014 | 6.12 uyarlaması (aşağıda) | bizim |

**Atlanan 8 yama** (`lts-hdmi` 0002–0004, 0006–0008, 0010, 0019): yalnız başka kartların (AM62,
BeagleY-AI) DTS dosyalarını veya DT binding şemalarını (`Documentation/devicetree/bindings`)
değiştiriyorlar; 6.12'de o dosyalar farklı olduğu için uymuyorlar. Bu kartın DTB'sini ve sürücüleri
etkilemezler.

Kart tanımı (DTS) bu yama setinde değil; `board/dts/` altından derlenir.

**0014, 6.12 uyarlaması** (`git show` ile tamamı görülür; 9 dosya, 71 ekleme / 49 silme):

| Yer | 6.18'de | 6.12'de kullanılan |
|---|---|---|
| tidss köprü `attach()` | `(bridge, encoder, flags)` | `(bridge, flags)`, kodlayıcı `bridge->encoder` |
| tidss OLDI `atomic_pre_enable/post_disable` | `drm_atomic_state` alır | `drm_bridge_state` alır, durum `->base.state` |
| `devm_drm_bridge_alloc()` | var (6.16) | `devm_kzalloc()` + `funcs` (`tidss_compat612.h`) |
| `auxiliary_device_destroy()` | var (6.16) | `delete` + `uninit` (`tidss_compat612.h`) |
| fbdev konsolu | `drm_client_setup()` | `drm_fbdev_dma_setup(ddev, 32)` |
| Kip değiştirme sırası | ayrık yardımcılar (OLDI için köprü önce) | 6.12'nin standart yardımcıları; bu kartın HDMI'ı DPI çıkışından, OLDI kullanmıyor |
| GPU `drm_gem_shmem_vmap_locked` | var | `drm_gem_shmem_vmap` (6.12'de aynı işlev bu adla) |
| GPU zamanlayıcı | `drm_sched_start(s, 0)`, `STAT_NO_HANG/RESET` | `drm_sched_start(s)`, `STAT_NOMINAL` |
| GPU adres alanı | `drm_gpuvm_sm_map(vm, priv, &req)` | `drm_gpuvm_sm_map(vm, priv, addr, range, obj, offset)` |
| `drm_sched_job_has_dependency()` | var (6.17) | aynı denetim, sürücü içinde |

**Durum:** Sürücüler 6.18'de denenmiş haliyle geliyor; uyarlama hatasız derleniyor ve bağlanıyor.
Masaüstü imajı kartta açıldı, ilk denemede sorunsuz (25 Kasım 2026). GPU (Vulkan) ve HDMI sesi
ayrıca ölçülmedi. Bu sıra değişikliği OLDI ekran kullanan kartlar için uygun değildir; bu kartta
OLDI yok.

**Yeniden üretmek:** hazırlanmış ağaç `kernels/trixie-hdmi/src` bir git deposudur
(`git log debian-6.12.118-1..HEAD`). Değişiklik orada commit'lenir, sonra:

```bash
cd kernels/trixie-hdmi/src
git format-patch --filename-max-length=40 --zero-commit -o ../patches debian-6.12.118-1..HEAD
```

Yeni bir Debian 6.12.y'de (`versions.env`) yamalar genelde uyar. Debian o sürümde `tidss` ya da
`imagination` klasörüne bir düzeltme almışsa 0001 uymaz ve `git am` orada durur; o zaman 0001
yeni 6.12.y'nin dosyalarına göre yeniden üretilir.
