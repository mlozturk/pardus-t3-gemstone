# T3 Gemstone O1 için kaynaktan derlenmiş Pardus 25

**Ne:** T3 Gemstone O1 geliştirme kartı (TI AM67A işlemcili, Raspberry Pi boyutunda bir bilgisayar)
için, **açılıştan masaüstüne kadar her parçası kaynak koddan bizim derlediğimiz** bir Pardus 25 sistemi
ve bunu tekrar tekrar üreten betikler.
**Durum (22 Kasım 2026):** Kart, tamamen bizim derlediğimiz zincirle Pardus 25 masaüstüne açılıyor.
**İki imajın çekirdeği de kernel.org'un uzun destekli 6.18 LTS sürümü** (destek Aralık 2028'e
kadar): masaüstlü `lite`, 6.18'e taşınmış HDMI yamalarıyla (`6.18.64-gemstone-hdmi+`, §27);
ekransız `minimal`, yamasız (`6.18.64-gemstone-mainline`, §24). Kartta HDMI görüntü, masaüstü,
**GPU (Vulkan)** ve iki **C7x DSP** çalışıyor (§23). Çekirdek SD kartı yeniden yazmadan ağ
üzerinden güncellenebiliyor (§22). Yayın imajları: §25. Önceki masaüstü çekirdeği Debian 7.2.12 +
HDMI yamaları (§21) seçenek olarak duruyor.
**Nerede derleniyor:** Pardus 25 (x86_64) derleme makinesi, klasör `~/gemstone/`.
**Başlangıç tarihi:** 5 Kasım 2026

> **Depo sürümü notu (15 Kasım 2026):** Betikler artık deponun bulunduğu klasörde çalışır
> (`~/gemstone` şartı yok) ve kaynaklar `scripts/00-fetch-sources.sh` ile indirilir. `03`
> **varsayılan olarak tamamen bizim zinciri (`-own`) üretir**; `.own-bl` / `.own-initrd`
> işaretlerine gerek kalmadı. T3'ün dosyalarıyla karşılaştırma için `VENDOR_BL=1` /
> `VENDOR_INITRD=1` (ya da `.vendor-bl` / `.vendor-initrd` işaretleri) kullanılır. BOOT
> bölümündeki kullanılmayan `initrd.img` ve `extlinux/` kaldırıldı. Kısa kullanım: depo kökündeki
> `README.md`. Aşağıdaki bölümlerde eski işaret adları geçen yerler bu nota göre okunmalı.

---

## Bir bakışta: ne yaptık?

1. **Kartın üreticisinin (T3) hazır sistemini kullanmadan**, kartı açan tüm yazılımları kaynak
   koddan derledik: bootloader (açılış yükleyicisi), Linux çekirdeği, initramfs ve Pardus.
2. Kartın neden ilk başta açılmadığını bulduk: SD karttaki açılış bölümünün **biçimi** (FAT32
   düzeni) kartın içindeki ROM'un okuyabileceği şekilde değildi. Düzelttik (§12 #20).
3. Pardus 25'i ARM kart için kurduk. Pardus ARM kartlar için resmi imaj yayınlamıyor; bizimki
   Pardus depolarından kurulmuş, resmi olmayan bir ARM sürümü (§15).
4. Biri tam (XFCE + LibreOffice + Firefox), biri **hızlı ve sade** (minimal Pardus XFCE) iki
   sürüm hazırladık (§19).
5. Kartın donanımını test ettik: Ethernet, Wi-Fi, Bluetooth, USB, PCIe, eMMC, sensörler, CAN,
   güvenli dünya (OP-TEE) çalışıyor (§13.4).
6. Kart üreticisinin (T3) çekirdeğinden kurtulduk: **Debian'ın çekirdek kaynağı + HDMI yamaları +
   kendi kart tarifimiz** ile `7.2.12-gemstone+` çekirdeğini derledik, kartta çalıştırdık ve açılış
   günlüğündeki (dmesg) hataları temizledik (§21).
7. Yeni çekirdeği kartı sökmeden, **SSH üzerinden** kurmanın yolunu hazırladık (§22).
8. **GPU'yu (PowerVR BXS-4-64) çalıştırdık**: ana Linux'un sürücüsü, TI'ın firmware'i ve Mesa 26 ile
   Vulkan kartta çalışıyor. Yapay zekâ hızlandırıcısı olan iki C7x DSP de açılıyor (§23).
9. **Hiç yama içermeyen** bir çekirdek seçeneği ekledik: kernel.org'un uzun destekli (LTS) 6.18
   sürümü, küçük bir ayarla; ekransız (HDMI'sız) kullanım için. (İlk sürümü 7.3.5'ti; kartta açıldı,
   sonra destek süresi uzun olsun diye 6.18 LTS'e geçildi.) Bununla en küçük sistem boyutu `minimal`'i
   hazırladık: 285 paket, 181 MB'lık imaj (§24).
10. İki imajı **yayınlanacak biçimde** (sıkıştırılmış imaj + SHA-256 özeti + sürüm notu) ürettik
    (§25, `docs/SURUM-NOTLARI.md`).
11. Betikleri düzenledik: her şey **tek komutla** (`./build.sh desktop` / `headless`), kart tanımı
    iki çekirdek için **tek kaynakta** (`board/dts/`), bütün sürümler **tek dosyada**
    (`versions.env`) (§26).

**Kartı açan zincir ve kimin olduğu:**

| Aşama | Ne işe yarar | Şimdi kimin |
|---|---|---|
| ROM | Yonganın içinde, SD karttan ilk dosyayı okur | TI (değiştirilemez) |
| Bootloader (3 dosya) | Belleği açar, güvenliği kurar, Linux'u yükler | **Bizim derlememiz** ✅ |
| TI güvenlik ve güç firmware'i | Bootloader'ın içine paketlenen kapalı parçalar | TI (kaynak kodu yayınlanmıyor) |
| Linux çekirdeği + donanım tarifi (DTB) | İşletim sisteminin kalbi | **Bizim derlememiz** ✅ (Debian 7.2.12 kaynağı + yamalar, §21; ya da yamasız 6.18 LTS, §24) |
| initramfs | Asıl sistemi bulup başlatır | **Bizim** (Debian aracıyla) ✅ |
| Pardus 25 | Masaüstü, programlar | **Bizim kurulumumuz** ✅ |

**Yayın imajları** (ayrıntı §25):

| İmaj | Ne için | Sıkıştırılmış |
|---|---|---|
| `t3-gem-o1-pardus-yirmibes-arm64-lite-20261122-own-klts-hdmi.img.xz` | **Masaüstü** (HDMI, Pardus XFCE, GPU), 6.18 LTS + HDMI yamaları | 423 MB |
| `t3-gem-o1-pardus-yirmibes-arm64-minimal-20261122-own-kmainline.img.xz` | **Ekransız** (SSH/seri konsol), yamasız 6.18 LTS çekirdek | 181 MB |

Giriş: `pardus` / `temppwd` (ilk girişte yeni şifre istenir).

**Kısa yol:** özet `docs/OZET.md`, adım adım üretim `docs/PROSEDUR.md`, HDMI çekirdek yamaları
(7.2 ↔ 6.18) `docs/HDMI-YAMALARI.md`.

**Bu belgeyi nasıl okumalı:**

| Kimsiniz | Okuyun |
|---|---|
| Ne yapıldığını merak eden | Bu sayfa + §3 (kart nasıl açılır) |
| Kartı kullanacak | **§25** (hangi imaj, nasıl yazılır), §13 (karta yazma ve test), §19 (sistem boyutları) |
| GPU / yapay zekâ ile uğraşacak | §23 (GPU, C7x DSP) |
| Sıfırdan derleyecek, konuya yeni | **§26** (tek komut), **§18** (adım adım rehber) |
| Bir şeyi değiştirecek | §16 (hangi dosyaya dokunulur) |
| Neden böyle yapıldığını soran | §11 (kararlar), §12 (yaşanan 20 sorun) |
| Çekirdekle uğraşacak | §20 (neden hazır çekirdek olmuyor), **§21** (Debian çekirdeği), **§22** (kartta güncelleme), **§24** (yamasız mainline çekirdek) |

---

## İçindekiler

1. [Durum tablosu: ne yapıldı, ne zaman](#1-durum-tablosu-ne-yapıldı-ne-zaman)
2. [Neden BeagleY-AI tabanlı?](#2-neden-beagley-ai-tabanlı)
3. [Kart nasıl açılır: bootloader'ı basitçe anlamak](#3-kart-nasıl-açılır-bootloaderı-basitçe-anlamak)
4. [Nerede ne var: dizin haritası](#4-nerede-ne-var-dizin-haritası)
5. [Kaynak kodlar ve sürümler](#5-kaynak-kodlar-ve-sürümler)
6. [Build ortamının kurulumu](#6-build-ortamının-kurulumu)
7. [Adım 1: Bootloader](#7-adım-1-bootloader--scripts01-bootloadersh)
8. [Adım 2: Kernel](#8-adım-2-kernel--scripts02-kernelsh)
9. [Adım 3: rootfs ve SD imajı](#9-adım-3-rootfs-ve-sd-imajı--scripts03-rootfs-imagesh)
10. [İmajın yapısı ve kartın açılışı](#10-imajın-yapısı-ve-kartın-açılışı)
11. [Tasarım kararları ve gerekçeleri](#11-tasarım-kararları-ve-gerekçeleri)
12. [Karşılaşılan sorunlar ve çözümleri](#12-karşılaşılan-sorunlar-ve-çözümleri)
13. [SD karta yazma ve kartta test](#13-sd-karta-yazma-ve-kartta-test)
14. [Açık konular ve sonraki adımlar](#14-açık-konular-ve-sonraki-adımlar)
15. [Hızlı başvuru: tüm build tek seferde](#15-hızlı-başvuru-tüm-build-tek-seferde)
16. [Kaynak haritası ve değişiklik rehberi](#16-kaynak-haritası-ve-değişiklik-rehberi)
17. [Kart özellikleri (T3 Gemstone O1)](#17-kart-özellikleri-t3-gemstone-o1)
18. [Sıfırdan rehber: kart nasıl açılır, her parça nerede ve nasıl derlenir](#18-sıfırdan-rehber-kart-nasıl-açılır-her-parça-nerede-ve-nasıl-derlenir) ← **konuya yeni başlayanlar buradan başlasın**
19. [Hafif sürüm (`lite`): minimal Pardus XFCE](#19-hafif-sürüm-lite-minimal-pardus-xfce)
20. [Neden Debian'ın hazır kernel'ini kullanamıyoruz? (Kernel kaynağı kararı)](#20-neden-debianın-hazır-kernelini-kullanamıyoruz-kernel-kaynağı-kararı)
21. [Debian çekirdeği: 7.2.12 + HDMI yamaları](#21-debian-çekirdeği-7212--hdmi-yamaları)
22. [Çekirdeği kartta güncellemek (SSH ile, SD kartı yazmadan)](#22-çekirdeği-kartta-güncellemek-ssh-ile-sd-kartı-yazmadan)
23. [GPU (PowerVR) ve C7x DSP'ler](#23-gpu-powervr-ve-c7x-dspler)
24. [Mainline çekirdek (yamasız) ve `minimal` sistem](#24-mainline-çekirdek-yamasız-ve-minimal-sistem)
25. [Yayın imajları ve seçenekler](#25-yayın-imajları-ve-seçenekler)
26. [Betiklerin düzeni (22 Kasım 2026)](#26-betiklerin-düzeni-22-kasım-2026)
27. [Masaüstü de LTS'te: 6.18 + HDMI yamaları](#27-masaüstü-de-lts-te-618--hdmi-yamaları-lts-hdmi-deneme)
28. [İkinci yayın: 7.3.5 çekirdekli imajlar](#28-ikinci-yayın-735-çekirdekli-imajlar-stable-stable-hdmi)

---

## 1. Durum tablosu: ne yapıldı, ne zaman

| Tarih | İş | Sonuç | Çıktı |
|---|---|---|---|
| 5 Kas | Derleme ortamı, çapraz derleyiciler, kaynak kodlar | ✅ | `~/gemstone/*` |
| 5 Kas | Bootloader derlemesi (TF-A, OP-TEE, U-Boot) | ✅ derlendi | `out/boot/tiboot3.bin`, `tispl.bin`, `u-boot.img` |
| 5 Kas | Kernel + modüller + DTB + `.deb` paketleri | ✅ derlendi (`6.12.24-t3-gem-o1+`) | `out/kernel/*.deb`, `out/boot/Image`, `*.dtb`, 35 overlay |
| 6 Kas | Debian 13 imajı | ⚠️ oluştu ama kart açılmadı | `…-debian-trixie-arm64-full-20261106.img` |
| 7–8 Kas | Pardus 25 imajı | ⚠️ oluştu ama kart açılmadı | `…-pardus-yirmibes-arm64-full-20261108.img` |
| 8 Kas | Kartın sağlamlık kontrolü: T3'ün kendi imajı | ✅ açıldı → sorun bizde | — |
| 8 Kas | Sorun bulundu: FAT düzeni + `uEnv.txt` (§12 #19, #20). T3'ün bootloader'ıyla Pardus (`-vboot`) | ✅ **ilk açılış** | `…-20261108-vboot.img` |
| 15 Kas | **Kendi bootloader'ımızla** (`-ownbl`) | ✅ açıldı | `…-20261115-ownbl.img` |
| 15 Kas | **Kendi initramfs'imiz** + ilk açılışta bölüm büyütme (`-own`) | ✅ açıldı, `/` = 30 GB. Zincirde T3 dosyası kalmadı | `…-arm64-full-20261115-own.img` |
| 15 Kas | Donanım testleri | ✅ çoğu çalışıyor (§13.4) | — |
| 15 Kas | **Minimal Pardus XFCE** (`lite`) | ✅ derlendi (832 paket, 710 MB); kartta 24 sn açılış, 480 MB bellek | `…-arm64-lite-20261115-own.img` |
| 16 Kas | Debian'ın hazır çekirdeği incelendi | ❌ HDMI yok (§20) | — |
| 16 Kas | **Debian 7.2.12 kaynağı + HDMI yamaları + kart tarifi** ile çekirdek | ⚠️ ilk deneme açılmadı (SD kart gücü gelmedi), ayar düzeltildi → ✅ HDMI + Ethernet çalışıyor | `kernels/debian/out/*.deb` |
| 16–17 Kas | Açılış günlüğündeki (dmesg) hataların temizlenmesi | ✅ 1.285 → 671 satır, çökme yok, taint 0 (§21.6) | `7.2.12-1gemstone1` |
| 17 Kas | Çekirdeği SSH ile kartta güncelleme | ⚠️ BOOT bölümü doldu, betik düzeltildi (§22.5) | `board/gemstone-kernel-update`, `scripts/05-kernel-deploy.sh` |
| 18 Kas | GPU: sürücü + firmware + Mesa 26; C7x DSP firmware'i | ✅ Vulkan çalışıyor, iki DSP açık (§23). Güncellemede kart U-Boot'ta kaldı, betik düzeltildi (§22.5.1) | yamalar 0023–0024 (o zamanki adları 0026–0027), `03` "2c" adımı |
| 18 Kas | Masaüstü yavaşlığı (Xorg glamor) | ✅ `AccelMethod none` ile düzeldi (§23.3) | `20-gemstone-noglamor.conf` |
| 18 Kas | **Yayın imajı: `lite` + Debian çekirdeği** | ✅ derlendi (817 paket, 634 MB); kartta denenmedi (aynı içerik kartta elle kurulup denendi) | `…-lite-20261118-own-kdebian.img.xz` |
| 21 Kas | **Yamasız mainline 7.3.5 çekirdeği** | ✅ derlendi (Image 28 MB, 852 modül); kartta henüz denenmedi | `kernels/mainline/out/` |
| 21 Kas | **Yayın imajı: `minimal` + mainline** | ✅ derlendi (285 paket, 195 MB); kartta henüz denenmedi | `…-minimal-20261121-own-kmainline.img.xz` |
| 22 Kas | `minimal` + mainline 7.3.5 imajı kartta | ✅ **açıldı** | — |
| 22 Kas | **Mainline seçeneği 6.18 LTS'e geçti** (destek Aralık 2028'e kadar); 7.3.5 kaldırıldı | ✅ derlendi (Image 26 MB, 771 modül), ekransız imaj yeniden üretildi (188 MB); ✅ **kartta açıldı, GPU çalışıyor** | `…-minimal-20261122-own-kmainline.img.xz` |
| 22 Kas | **Masaüstü de 6.18 LTS'te**: HDMI yamaları 6.18'e taşındı (§27); imajlardan derleyici ve kullanılmayan firmware çıkarıldı; HDMI ses saati ve `playback-only` düzeltildi | ✅ kartta HDMI görüntü ve masaüstü; ses sürücüsü hatasız | `…-lite-20261122-own-klts-hdmi.img.xz` |
| 22 Kas | **İkinci yayın: 7.3.5 çekirdekli imajlar** (§28): HDMI yamaları 7.3'e taşındı (21 yama) | ✅ iki çekirdek ve iki imaj derlendi, denetlendi; kartta henüz denenmedi | `release/2026.11-7.3/` |
| 22 Kas | **Betiklerin düzenlenmesi** (§26): tek komut `build.sh`, tek kart tanımı `board/dts/`, sürümler `versions.env`'de, yayın betiği `06`, `04` `.xz` yazıyor; eski imajlar ve denemeler temizlendi (21 GB) | ✅ iki DTB eskisiyle aynı; yayın imajları yeni betiklerle yeniden üretildi | `release/2026.11/` |

Tüm süreç tek komutla tekrarlanabilir: `./build.sh desktop` ya da `./build.sh headless` (§26).
Adım betikleri (`scripts/00`–`06`, `kernels/*/build.sh`) tek tek de çalışır ve kaldığı yerden
devam eder.

---

## 2. Neden BeagleY-AI tabanlı?

- **Aynı işlemci.** T3 Gemstone O1 ve BeagleY-AI aynı SoC'yi kullanır: **Texas Instruments AM67A**
  (TI iç adıyla **J722S**). 4× Cortex-A53 uygulama çekirdeği, Cortex-R5F açılış/yönetim çekirdekleri,
  C7x DSP/AI hızlandırıcı ve aynı açılış mimarisi. Bu yüzden açılış zinciri, firmware dosyaları
  ve derleme yöntemi büyük ölçüde ortak.
- **Olgun ve açık build akışı.** BeagleBoard.org Debian imajlarını herkese açık betiklerle
  üretir: kernel.org GCC araç zinciri, TI'ın `ti-linux-firmware` deposu, TF-A + OP-TEE + U-Boot
  binman akışı, extlinux ile açılış. Bu akış AM67A üzerinde sahada denenmiş.
- **T3 kendi fork'larını bu temele kurmuş.** `t3gemstone/u-boot` ve `t3gemstone/linux` depoları,
  BeagleBoard'un U-Boot ve TI kernel ağaçlarının üzerine Gemstone O1 kart desteği eklenmiş halleri.
  Depolarda BeagleY-AI defconfig'leri ve DTS'leri de duruyor. Gemstone O1 dosyaları bunların
  yanında ve aynı kalıpla yazılmış.

Kısacası **yöntem BeagleY-AI'den, karta özel dosyalar T3'ün depolarından** geliyor.

| Bileşen | BeagleY-AI | T3 Gemstone O1 (bu projede kullanılan) |
|---|---|---|
| U-Boot R5 defconfig | `am67a_beagley_ai_r5_defconfig` | `am67a_t3_gem_o1_r5_defconfig` |
| U-Boot A53 defconfig | `am67a_beagley_ai_a53_defconfig` | `am67a_t3_gem_o1_a53_defconfig` |
| U-Boot kart kodu | `board/beagle/beagley-ai/` | `board/t3/t3-gem-o1/` |
| Kernel defconfig | `bb.org_defconfig` | `t3_gem_o1_defconfig` |
| Ana device tree | `k3-am67a-beagley-ai.dtb` | `k3-am67a-t3-gem-o1.dtb` |
| Overlay'ler | `k3-am67a-beagley-ai-*.dtbo` | `k3-am67a-t3-gem-o1-*.dtbo` (kamera, DSI panel, PWM, SPI, UART, fan…) |
| Wi-Fi / Bluetooth | — | Realtek **RTL8822CS** (SDIO + UART), `firmware-realtek` |
| Seri konsol | `ttyS2`, 115200 8N1 | `ttyS2`, 115200 8N1 |

---

## 3. Kart nasıl açılır: bootloader'ı basitçe anlamak

### 3.1 Önce bir benzetme

Bir PC'de güç düğmesine basınca **BIOS** çalışır, diskteki **GRUB**'u bulur, GRUB da **Windows'u
ya da Linux'u** başlatır. Bu karttaki fikir aynı, yalnızca daha fazla basamak var.

Neden fazla basamak? Güç verildiği anda kartın 4 GB'lık belleği (RAM) **henüz çalışmıyor**. Onu
çalıştırabilmek için bile önce küçük bir programın çalışması gerekiyor. Bu yüzden açılış, her biri
bir sonrakinin işini mümkün kılan küçük adımlardan oluşan bir **bayrak yarışı** gibi:

```
  Güç   →   ① ROM   →   ② tiboot3.bin   →   ③ tispl.bin   →   ④ u-boot.img   →   ⑤ Linux   →   ⑥ Pardus
           (yongada)    "belleği aç"        "güvenliği kur"     "Linux'u bul"     (çekirdek)    (masaüstü)
```

**Bootloader** = ②, ③ ve ④. SD kartın küçük `BOOT` bölümünde üç ayrı dosya olarak durur.

### 3.2 Her koşucu ne yapıyor?

| # | Kim | Ne yapar (basitçe) | Benzetme |
|---|---|---|---|
| ① | **ROM** (yonganın içinde) | Kartın üzerindeki anahtarlara bakar, SD kartı açar, `BOOT` bölümünden `tiboot3.bin`'i okur | PC'nin BIOS'u |
| ② | **tiboot3.bin** | Küçük yardımcı işlemcide (R5F) çalışır. **Belleği (RAM) çalıştırır**, saatleri ve güç hatlarını ayarlar. İçinde TI'ın güvenlik firmware'i de var | Binanın elektriğini ve suyunu açan görevli |
| ③ | **tispl.bin** | Ana işlemcide (4 × A53) çalışır. **Güvenlik katmanlarını** kurar: TF-A (kapı bekçisi), OP-TEE (gizli kasa, §18.3) ve güç yönetimi (DM) | Güvenlik sistemini ve kasayı kuran görevli |
| ④ | **u-boot.img** | Artık her şey hazır: SD kartı, dosyaları, Ethernet'i tanır. `uEnv.txt`'deki ayarlarımızı okur, Linux'u belleğe yükler ve başlatır | PC'deki GRUB |
| ⑤ | **Linux** (`Image` + `.dtb` + initramfs) | Donanımı tanır, asıl sistemi (SD kartın büyük bölümü) bulup bağlar | — |
| ⑥ | **Pardus** | Servisler, ağ, giriş ekranı, XFCE masaüstü | — |

**Bir koşucu düşerse yarış orada biter.** Bu yüzden kart açılmadığında önce "hangi koşucuya kadar
gelindi?" sorusu sorulur. Seri kablomuz olmadığı için bunu Ethernet üzerinden anlıyoruz: ④ U-Boot
ayarlarımızı okuyunca bilgisayara bir "buradayım" sinyali gönderiyor (§13.2.1).

### 3.3 Neden üç ayrı dosya?

Çünkü üçü **farklı işlemcilerde** çalışıyor ve farklı derleyicilerle üretiliyor:

| Dosya | Çalıştığı işlemci | İçindekiler | Derleyici |
|---|---|---|---|
| `tiboot3.bin` | R5F (32-bit, küçük yardımcı) | U-Boot'un küçük hali (SPL) + TI güvenlik firmware'i (TIFS) + kart ayarları | `arm-linux-gnueabi-` |
| `tispl.bin` | A53 (64-bit, ana işlemci) | TF-A + OP-TEE + U-Boot'un küçük hali + TI güç firmware'i (DM) | `aarch64-linux-` |
| `u-boot.img` | A53 | U-Boot'un tam hali | `aarch64-linux-` |

Üçünü de **tek bir betik** üretiyor: `scripts/01-bootloader.sh` (~3 dakika, §7). Kaynaklar: T3'ün
U-Boot'u (`github.com/t3gemstone/u-boot`), TF-A, OP-TEE ve TI'ın firmware deposu (§5).

### 3.4 `uEnv.txt`: bootloader'a verdiğimiz talimat

`BOOT` bölümündeki `uEnv.txt` düz bir metin dosyası; herhangi bir metin düzenleyiciyle açılıp
değiştirilebilir. U-Boot açılırken onu okur. İçinde şunlar var:

| Satır | Ne demek |
|---|---|
| `ipaddr=10.42.0.12`, `serverip=10.42.0.11` | U-Boot'un Ethernet'te kullanacağı adresler ("buradayım" sinyali için) |
| `optargs=… console=tty1 quiet …` | Linux'a verilecek ek ayarlar (ekran konsolu, sessiz açılış) |
| `args_mmc=…` | Linux'un asıl sistemi nerede bulacağı: SD kartın 2. bölümü, btrfs |
| `boot_mmc=…` | Hangi dosyaları yükleyip Linux'u başlatacağı: `Image`, `.dtb`, initramfs |

**Öğrendiğimiz ders (§12 #19):** T3'ün U-Boot'u, çoğu kartta kullanılan `uenvcmd` satırını okuduktan
hemen sonra siliyor. Bu yüzden ilk kartlarımız açılmadı. Doğru yol `args_mmc` ve `boot_mmc`
satırlarını yeniden tanımlamak.

### 3.5 Kartı ilk başta neden açamadık?

İki sorun üst üste geldi:

1. **FAT biçimi (asıl sorun, §12 #20):** ① ROM, `BOOT` bölümünü kendi küçük okuyucusuyla okuyor ve
   bu okuyucu yalnızca belirli bir FAT32 düzenini anlıyor (128 MB, 512 baytlık küme, özel disk
   geometrisi). Standart biçimlendirme ile oluşturduğumuz bölümü okuyamadı. Bu yüzden kartta hiçbir
   ışık, ekran ya da ağ sinyali yoktu. T3'ün çalışan kartını inceleyip aynı düzeni kopyaladık.
2. **`uEnv.txt` talimatı (§12 #19):** Yukarıda anlatılan `uenvcmd` sorunu.

İkisi düzelince kart önce T3'ün bootloader'ıyla, sonra **bizim derlediğimiz bootloader'la** açıldı.
Yani bootloader'ımız baştan beri doğruydu; sorun SD kartın hazırlanışındaydı.

### 3.6 Bizim imajımızda zincir (teknik özet)

```
 Güç
  └─ ROM (TI)                      SD kart, FAT32 BOOT bölümü (T3 düzeni)
      └─ tiboot3.bin   [R5F]       U-Boot R5 SPL + TIFS + kart ayarları   ← 01-bootloader.sh
          └─ tispl.bin [A53]       TF-A BL31 + OP-TEE + A53 SPL + DM      ← 01-bootloader.sh
              └─ u-boot.img [A53]  T3 env: bootcmd → envboot (uEnv.txt) → bootcmd_mmc
                  │                = args_mmc + boot_mmc (uEnv.txt'de yeniden tanımlı)
                  └─ Image + k3-am67a-t3-gem-o1.dtb + initramfs           ← 02-kernel.sh, 03
                      │   root=/dev/mmcblk1p2 rootfstype=btrfs
                      └─ initramfs-tools → Pardus 25: systemd → LightDM → XFCE  ← 03-rootfs-image.sh
```

Aşamaların ayrıntılı tablosu (her aşama bozulursa ne görülür): §18.2.

---

## 4. Nerede ne var: dizin haritası

### 4.1 Depo dizini

```
~/gemstone/
│
├── README.md                    ← kısa kullanım (depo ana sayfası)
├── docs/
│   ├── BELGE.md                 ← bu doküman
│   ├── PROSEDUR.md              ← kısa adım adım prosedür
│   ├── SURUM-NOTLARI.md         ← yayın imajlarının sürüm notu
│   └── pardus-yirmibes-paketler.tsv ← Pardus imajındaki 1786 paket: sürüm, mimari, depo, not (§15)
├── build.sh                     ← TEK KOMUT: ./build.sh desktop | headless | image (§26)
├── versions.env                 ← sabitlenen bütün sürümler (derleyici, kaynaklar, çekirdekler)
├── go-pardus, go                ← yalnız 03 için sudo kısa yolları (seçenekleri 03'e geçirir)
│
├── scripts/
│   ├── 00-fetch-sources.sh      derleyiciler + kaynaklar (versions.env'deki sürümler)
│   ├── 01-bootloader.sh         TF-A + OP-TEE + U-Boot R5/A53 → tiboot3/tispl/u-boot.img
│   ├── 02-kernel.sh             T3 kernel'i + modüller + DTB/DTBO + Debian .deb paketleri
│   ├── 03-rootfs-image.sh       Pardus/Debian rootfs + SD imajı (root yetkisi gerekir; --help)
│   ├── 04-flash-sd.sh           imajı (.img ya da .img.xz) SD karta yazar ve doğrular
│   ├── 05-kernel-deploy.sh      Debian ya da mainline çekirdeği SSH ile çalışan karta kurar (§22)
│   └── 06-release.sh            yayın klasörü: release/<sürüm>/ (§25)
│
├── board/
│   ├── dts/                     KART TANIMI, iki çekirdek için tek kaynak + build-dtb.sh (§21.4)
│   └── gemstone-kernel-update   kartta /usr/local/sbin'e kurulan güncelleme betiği (§22)
├── kernels/debian/              DEBIAN ÇEKİRDEĞİ (§21)
│   ├── build.sh                 indir + yamala + derle (depoda)
│   ├── patches/                 24 yama + README (depoda)
│   ├── src/  build/             Debian kaynağı (git) ve derleme dizini (derlemede oluşur)
│   └── out/                     .deb, Image, DTB, release (derlemede oluşur)
├── kernels/mainline/            MAINLINE ÇEKİRDEK, yamasız (§24)
│   ├── build.sh                 kernel.org arşivi + ayar + derleme (depoda)
│   ├── linux-6.18.64.tar.xz     indirilen arşiv (LTS); src/ build/ derlemede oluşur
│   └── out/                     .deb, Image, DTB, release (derlemede oluşur)
├── release/<sürüm>/             yayın klasörleri (06-release.sh; imajlar out/'a sabit bağlantı)
│
├── gcc-11.5.0-nolibc/           ÇAPRAZ DERLEYİCİLER (kernel.org)
│   ├── aarch64-linux/bin/aarch64-linux-*        64-bit: TF-A, OP-TEE, U-Boot A53, Linux
│   └── arm-linux-gnueabi/bin/arm-linux-gnueabi-* 32-bit: U-Boot R5 SPL, OP-TEE 32-bit parçaları
│
├── u-boot/                      KAYNAK: t3gemstone/u-boot
├── linux/                       KAYNAK: t3gemstone/linux
├── trusted-firmware-a/          KAYNAK: TF-A lts-v2.12.4
├── optee_os/                    KAYNAK: OP-TEE 4.6.0
├── ti-linux-firmware/           KAYNAK: TI ikili firmware'leri (TIFS, DM), BeagleBoard aynası
│
├── patches/
│   └── linux-0001-dts-ti-do-not-list-pinmux-dtsi-as-dtb.patch   T3 kernel ağacına uygulanan yerel düzeltme (§12)
│
├── build-user/                  ARA ÇIKTILAR, normal kullanıcı (01 ve 02 betikleri)
│   ├── tfa/k3/lite/release/bl31.bin
│   ├── optee/core/tee-pager_v2.bin
│   ├── uboot-r5/                R5 U-Boot derleme dizini (O=)
│   ├── uboot-a53/               A53 U-Boot derleme dizini (O=)
│   └── linux/                   Kernel derleme dizini (O=), .config burada
│
├── build/                       ARA ÇIKTILAR, root (03 betiği)
│   ├── debian-archive-keyring.gpg   Debian'ın güncel arşiv anahtarlığı (debootstrap için)
│   ├── rootfs-pardus-yirmibes[-lite|-minimal]/   Pardus kök dosya sistemleri, boyut başına bir tane
│   ├── rootfs-trixie/           Debian 13 kök dosya sistemi (6 Kasım'dan beri kullanılmıyor, silinebilir)
│   └── bootfs/                  SD kartın BOOT bölümüne giden dosyaların hazırlandığı yer
│
├── build-chain.sh               (eski) bootloader + kernel'i arka planda sırayla çalıştıran yardımcı; yerini build.sh aldı
│
├── out/                         NİHAİ ÇIKTILAR
│   ├── boot/
│   │   ├── tiboot3.bin          (= tiboot3-j722s-hs-fs-evm.bin, seri üretim HS-FS silikon)
│   │   ├── tiboot3-j722s-hs-evm.bin   (HS-SE: secure boot'u kilitli silikon için)
│   │   ├── tispl.bin
│   │   ├── u-boot.img
│   │   ├── Image                Linux kernel (sıkıştırılmamış arm64 Image)
│   │   ├── k3-am67a-t3-gem-o1.dtb
│   │   └── overlays/*.dtbo
│   ├── kernel/
│   │   ├── linux-image-<sürüm>_1gemstone_arm64.deb
│   │   ├── linux-headers-…, linux-libc-dev-….deb
│   │   └── release              kernel sürüm dizgesi (03 betiği bunu bekler)
│   ├── t3-gem-o1-pardus-yirmibes-arm64-<boyut>-AAAAGGAA-own[-k<çekirdek>].img  ← ham SD imajı
│   ├── …img.xz                                              ← dağıtım için sıkıştırılmış
│   └── …img.sha256                                          (eski imajların yalnızca .xz'i tutuluyor)
│
├── out-<boyut>-<çekirdek>.log  out-bootloader.log  out-pardus.log   ← derleme günlükleri
│
└── x86_64-gcc-11.5.0-nolibc-*.tar.xz   derleyici arşivleri (açılmış hali gcc-11.5.0-nolibc/)
```

---

## 5. Kaynak kodlar ve sürümler

Kesin commit'ler aşağıda. Aynı imajı yeniden üretmek için bu commit'lere `git checkout` yapmak yeterli.

| Bileşen | Depo | Branch / etiket | Commit | Neden bu sürüm |
|---|---|---|---|---|
| U-Boot | `github.com/t3gemstone/u-boot` | `v2025.04-rc3-t3-gem-o1` | `b8410d78120` (2026-08-11) | T3'ün Gemstone O1 kart desteğini içeren tek ağaç. BeagleBoard'un v2025.04 tabanı. |
| Linux | `github.com/t3gemstone/linux` | `v6.12.24-ti-arm64-r43-t3-gem-o1` | `6267aeaee` (2026-09-03) | BeagleBoard'un TI 6.12 LTS kerneli + Gemstone O1 DTS/defconfig. AM67A'nın GPU, kamera ve DSP sürücüleri TI ağacında. |
| TF-A | `github.com/TrustedFirmware-A/trusted-firmware-a` | `lts-v2.12.4` | `a9fcaf3` | Uzun süreli destekli sürüm. K3 `lite` platformunu içerir. |
| OP-TEE | `github.com/OP-TEE/optee_os` | `4.6.0` | `7178564` | U-Boot 2025.04 ve TF-A 2.12 ile uyumlu kararlı sürüm. |
| TI firmware | `github.com/beagleboard/ti-linux-firmware` | etiket `11.01.03` | `e594deb` | TIFS ve DM ikilileri. BeagleY-AI build'inin kullandığı ayna. |
| Çapraz derleyici | kernel.org crosstool | GCC 11.5.0 nolibc | — | BeagleY-AI bootloader betikleriyle aynı. U-Boot/TF-A/OP-TEE/kernel için libc gerekmez, dağıtımdan bağımsız ve tekrarlanabilir. |
| Debian | `deb.debian.org` | 13 "trixie" (arm64) | — | Güncel kararlı Debian. BeagleBoard'un güncel AM67A imajları da Debian 13 tabanlı. |
| Pardus | `depo.pardus.org.tr/pardus` (`yirmibes`, `yirmibes-deb`), `depo.pardus.org.tr/guvenlik` | 25.2 "yirmibes" (arm64) | — | Pardus'un güncel ana sürümü, Debian 13 tabanlı. Kaynak paketler aynı depoda (`…/main/source/Sources.gz`). |
| T3 boot dosyaları (`-vboot`) | T3'ün resmi imajı `gemstone-desktop-v2026.1-ubuntu-jammy-t3-gem-o1.img.xz` | v2026.1 | U-Boot `b8410d78120e`, TF-A `v2.13.0-259-ge0c4d3903b-dirty` | Kartta açıldığı kanıtlanmış bootloader ve initramfs. Ayrıntı: §10.1, §16 |

Kaynak kodun tamamı ve her parçada nereye dokunulacağı için bkz. **§16**.

---

## 6. Build ortamının kurulumu

### 6.1 Derleme makinesi gereksinimleri

| Ayar | Değer | Neden |
|---|---|---|
| İşletim sistemi | Pardus 25 (x86_64); Debian 13 tabanlı her dağıtım olur | TI ve BeagleBoard araçları Debian 13 tabanında sorunsuz. |
| vCPU | 4 (en fazla 8) | Daha fazlası derlemeyi hızlandırır; sanal makinede sanallaştırma katmanı kararsızlık yaratıyorsa 4 vCPU güvenli (bkz. §12). |
| RAM | 4–6 GB | Sanal makinede host'ta gerçekten boş olandan fazlası verilmez. |
| Disk | 60–100 GB | Tüm build + imaj ~25–30 GB tutar, rahat pay bırakılır. |
| Ağ | internet | Kaynaklar ve Pardus paketleri indirilir. |

### 6.2 Kurulan host paketleri

```bash
sudo apt-get update
sudo apt-get install -y \
  git make bison flex bc swig \
  libssl-dev libgnutls28-dev uuid-dev libncurses-dev libelf-dev libdw-dev \
  python3-setuptools python3-pyelftools python3-dev python3-cryptography python3-yaml \
  python3-jsonschema yamllint \
  device-tree-compiler u-boot-tools \
  debootstrap debian-archive-keyring qemu-user-static binfmt-support \
  parted kpartx dosfstools e2fsprogs btrfs-progs rsync \
  lz4 lzop xz-utils zstd cpio kmod ccache fakeroot dpkg-dev debhelper \
  openssh-server
```

Paketlerin ne işe yaradığı:

- `swig`, `python3-setuptools`, `python3-dev`: U-Boot'un Python libfdt bağlaması. **binman** bunu
  kullanarak tiboot3/tispl imajlarını paketler. İlk elle denemede `setuptools` eksikti ve U-Boot
  derlemesi bu yüzden durmuştu.
- `python3-pyelftools`, `python3-cryptography`, `python3-yaml`, `python3-jsonschema`, `yamllint`:
  binman'ın TI imaj imzalama ve board-config (`*.yaml`) doğrulama adımları.
- `libssl-dev`, `libgnutls28-dev`, `uuid-dev`: U-Boot host araçları (`mkimage`, `mkeficapsule`).
- `bison`, `flex`, `bc`, `libelf-dev`, `libncurses-dev`: kernel derlemesi.
- `fakeroot`, `dpkg-dev`, `debhelper`: kernel'den `.deb` paketi üretmek için (`make bindeb-pkg`).
- `debootstrap`, `debian-archive-keyring`: Debian kök dosya sistemini sıfırdan kurmak ve paket imzalarını doğrulamak.
- `qemu-user-static`, `binfmt-support`: x86 makinede arm64 programlarını çalıştırmak, yani arm64
  rootfs'e `chroot` edip `apt` ile paket kurabilmek.
- `parted`, `dosfstools`, `btrfs-progs`, `rsync`, `xz-utils`: disk imajını bölümlemek, biçimlendirmek, doldurmak ve sıkıştırmak.

### 6.3 Kaynakların indirilmesi (sıfırdan kurulumda)

```bash
./scripts/00-fetch-sources.sh      # ./build.sh eksikse kendisi çalıştırır
```

Betik kernel.org'un GCC 11.5.0 çapraz derleyicilerini indirir; U-Boot, T3 Linux, TF-A, OP-TEE ve
TI firmware ağaçlarını **`versions.env`'de yazan commit'lerle** klonlar ve T3 Linux'a yerel
düzeltmeyi (`patches/linux-0001…`, §12 madde 11) uygular. Yeniden çalıştırmak güvenlidir. Sürüm
değiştirmek için yalnızca `versions.env` düzenlenir; Debian ve mainline çekirdeklerinin sürümleri
ve özetleri de oradadır.

---

## 7. Adım 1: Bootloader (`scripts/01-bootloader.sh`)

```bash
cd ~/gemstone && ./scripts/01-bootloader.sh 2>&1 | tee out-bootloader.log
```

Süre: ~3 dakika. Root yetkisi gerekmez.

| # | Ne yapar | Komut özü | Çıktı | Neden böyle |
|---|---|---|---|---|
| 1 | **TF-A** | `make PLAT=k3 TARGET_BOARD=lite SPD=opteed` | `build-user/tfa/k3/lite/release/bl31.bin` | AM62/AM67 ailesi TF-A'da `k3` platformunun `lite` kartı. `SPD=opteed`, OP-TEE'ye geçişi etkinleştirir. |
| 2 | **OP-TEE** | `make PLATFORM=k3-am62x CFG_ARM64_core=y` | `build-user/optee/core/tee-pager_v2.bin` | J722S, OP-TEE'de AM62x platform tanımını paylaşır (TI SDK ve BeagleY-AI aynı ayarı kullanır). 64-bit çekirdek. |
| 3 | **U-Boot R5** | `am67a_t3_gem_o1_r5_defconfig` + `make BINMAN_INDIRS=ti-linux-firmware` | `tiboot3-j722s-hs-fs-evm.bin`, `tiboot3-j722s-hs-evm.bin` | R5 SPL, Gemstone O1'in **DDR ayarlarını** (`k3-am67a-t3-gem-o1-ddr-lp4.dtsi`) içerir. Karta özel en kritik parça budur. binman, SPL'i TIFS firmware ve board config ile birleştirip imzalar. |
| 4 | **U-Boot A53** | `am67a_t3_gem_o1_a53_defconfig` + `make BL31=… TEE=… BINMAN_INDIRS=…` | `tispl.bin`, `u-boot.img` | binman, TF-A + OP-TEE + A53 SPL + DM firmware'i `tispl.bin` içinde paketler. |

**HS-FS ve HS-SE:** AM67A silikonu iki güvenlik modunda gelir. Seri üretim kartlar **HS-FS**
(field securable, anahtar yakılmamış) olduğu için varsayılan `tiboot3.bin` HS-FS sürümüdür.
Kartta secure boot anahtarları yakılmışsa (HS-SE) `tiboot3-j722s-hs-evm.bin` kullanılmalıdır.

**Doğrulama:** Derleme hatasız bitti ve binman eksik blob uyarısı vermedi. Boyutlar: tiboot3.bin
404 KB, tispl.bin 980 KB, u-boot.img 978 KB. A53 yapılandırmasında
`CONFIG_TARGET_J722S_A53_T3_GEM_O1=y` ve `CONFIG_DEFAULT_DEVICE_TREE="ti/k3-am67a-t3-gem-o1"`
var; doğru kart hedefleniyor.

---

## 8. Adım 2: Kernel (`scripts/02-kernel.sh`)

```bash
cd ~/gemstone && JOBS=4 ./scripts/02-kernel.sh 2>&1 | tee out-kernel.log
```

Süre: 4 vCPU'da ~45–60 dakika. Root yetkisi gerekmez.

Yaptıkları:

1. `t3_gem_o1_defconfig`: T3'ün kart için hazırladığı yapılandırma (AM67A sürücüleri, RTL8822CS,
   kamera/DSI, ~2800 modül).
2. Üzerine Debian için gereken birkaç seçenek `scripts/config` ile açılır:
   - `BTRFS_FS`: kök dosya sistemi btrfs (T3'ün kendi imaj düzeniyle aynı, bkz. §11)
   - `BLK_DEV_INITRD`, `DEVTMPFS(_MOUNT)`, `CGROUPS`, `AUTOFS_FS`, `FHANDLE`, `SECCOMP`: systemd'nin gereksinimleri
   - `MODULE_SIG_ALL` kapalı, `SYSTEM_TRUSTED_KEYS` boş: imzalama anahtarı yönetimiyle uğraşmamak için
   - `DEBUG_INFO_BTF` kapalı: `pahole` bağımlılığı olmasın ve derleme kısalsın
   - `LOCALVERSION=-t3-gem-o1`: kernel sürümünde kart adı görünsün (`uname -r`)
3. `make Image modules dtbs`: kernel, modüller, tüm device tree ve overlay'ler.
4. `make bindeb-pkg`: **Debian paketleri**. Rootfs'e `dpkg -i` ile kurulur. Böylece modüller
   `/lib/modules` altına düzgün yerleşir ve ileride kernel güncellemesi paketle yapılabilir.
5. `Image`, `k3-am67a-t3-gem-o1.dtb` ve `overlays/*.dtbo` dosyaları `out/boot/` altına kopyalanır.
   Kernel sürüm dizgesi `out/kernel/release` dosyasına yazılır.

---

## 9. Adım 3: rootfs ve SD imajı (`scripts/03-rootfs-image.sh`)

```bash
./build.sh desktop          # önceki adımlarla birlikte; 03'ü sudo ile kendisi çalıştırır (§26)
sudo ./scripts/03-rootfs-image.sh --distro pardus --flavor minimal --kernel mainline   # yalnız bu adım
sudo ./go-pardus --flavor minimal --kernel mainline                                    # aynısı, günlüklü
```

Süre: ilk kurulum ~45–75 dakika (paketler internetten iner, ARM programları `qemu` ile taklit
edilir); sonraki imaj üretimleri ~10–20 dakika. **Root yetkisi gerekir** (chroot, loop aygıtı, mount).

Seçenekler komut satırından verilir (`--help`; tam tablo §25.3): `--flavor` (`lite` varsayılan,
`full`, `minimal`), `--kernel` (`lts-hdmi` varsayılan, `mainline`, `debian`, `t3`), `--distro`, `--xz N`.
Bootloader ve initramfs varsayılan olarak bizimdir (`-own`); T3'ün dosyalarıyla karşılaştırma
için `--vendor-bl` / `--vendor-initrd`. Eski işaret dosyaları (`.flavor`, `.kernel`, `.lite`,
`.vendor-*`) hâlâ okunur ama komut satırı önce gelir.

| Aşama | Ne yapar | Neden |
|---|---|---|
| 0 | Saat kontrolü; eksik host araçlarını kurar | apt imzaları saat yanlışsa reddedilir; uzun kurulum eksik araç yüzünden boşa gitmesin |
| 1 | `debootstrap --foreign --arch=arm64` + `qemu-aarch64-static` ile ikinci aşama (`.stage1-done`) | x86 makinede arm64 kök dosya sistemi |
| 2 | Kernel bitene kadar bekler (`out/kernel/release`) | Betik kernel ile paralel başlatılabilir |
| 3 | Pardus depoları (`yirmibes`, `yirmibes-deb`, `guvenlik`), hostname `gemstone`, `/etc/fstab`, Türkçe yerel ayar | Wi-Fi/BT firmware'i `non-free-firmware` bileşeninde |
| 4 | Paket kurulumu (chroot içinde): `full`, `lite` ya da `minimal` listesi (§15, §19, §24.3) | — |
| 5 | Bizim kernel `.deb`'imiz kurulur, `update-initramfs` initramfs'i üretir | Kernel güncellemesi paketle yapılabilsin |
| 5b ("2c") | Başka çekirdek paketleri ve modül klasörleri silinir (rootfs'te tek çekirdek kalır). GPU ve C7x firmware'i; masaüstlülerde Mesa 26 + `noglamor` ayarı; `lite`/`minimal`'de geliştirme araçları, belgeler ve fazla diller silinir | §23, §19. İşaretler: `.gpu-1`, `.slim-1` |
| 6 | Kullanıcı `pardus` / `temppwd`; ilk girişte şifre değiştirme zorunlu (`chage -d 0`) | Varsayılan şifre kalıcı kalmasın |
| 7 | SSH host anahtarları ilk açılışta üretilir (`regen-ssh-keys.service`) | Her kartın kendi anahtarı olsun |
| 8 | Ağ: sabit IP `10.42.0.12/24`, `gemstone-beacon` (5 sn'de bir PC'ye ping), `gemstone-growroot` (ilk açılışta bölüm büyütme) | Seri kablo olmadan izlenebilsin; kartın tamamı kullanılsın |
| 9 | BOOT bölümü içeriği (`build/bootfs/`): bootloader, kernel, DTB, overlay'ler, initramfs, `uEnv.txt` | §10 |
| 10 | İmaj: MBR, p1 FAT32 **128 MB (T3 düzeni)**, p2 btrfs (zstd); `full` 12 GB, `lite` 8 GB, `minimal` 4 GB. Bölümlerin görünmesi beklenir (en çok 30 sn) | §10, §12 #20 |
| 11 | `xz` sıkıştırma ve `sha256` (dosya adları yolsuz yazılır, imajın yanında `sha256sum -c` ile denetlenir) | Dağıtım ve bütünlük kontrolü |

Kurulan paketlerin tam listesi (sürüm, mimari, depo): `pardus-yirmibes-paketler.tsv` (§15).

---

## 10. İmajın yapısı ve kartın açılışı

```
t3-gem-o1-pardus-yirmibes-arm64-<full|lite>-AAAAGGAA-own.img   (MBR)
├── p1  BOOT    FAT32  128 MB   → kartta /boot/firmware; FAT32 her sistemde "BOOT" sürücüsü
│   │           (boot bayrağı, 512 B küme, gizli sektör 0, geometri 16/32 — T3 düzeni, §12 #20)
│   ├── tiboot3.bin                          ① ROM'un okuduğu ilk dosya        (01-bootloader.sh)
│   ├── tispl.bin                            ② TF-A + OP-TEE + SPL + DM        (01-bootloader.sh)
│   ├── u-boot.img                           ③ U-Boot                          (01-bootloader.sh)
│   ├── uEnv.txt                             U-Boot'a talimatlarımız (düz metin) (03)
│   ├── Image                                Linux çekirdeği                   (02-kernel.sh)
│   ├── k3-am67a-t3-gem-o1.dtb               donanım tarifi                    (02-kernel.sh)
│   ├── overlays/*.dtbo                      isteğe bağlı donanım (kamera, ekran…) (02-kernel.sh)
│   ├── gemstone-image-rd-t3-gem-o1.cpio.gz  initramfs (adı T3'ten kalma; U-Boot bu adı arıyor) (03)
│   └── initrd.img, extlinux/                kullanılmıyor (eski yöntemden kalan kopya)
└── p2  rootfs  btrfs (zstd)     → kartta /   Pardus 25; ilk açılışta kartın tamamına büyür
```

**Neden FAT ilk bölüm?** Kartın ROM'u SD karttan açılırken ilk FAT bölümünde `tiboot3.bin`'i arar.
U-Boot da diğer dosyaları aynı yerden okur. ROM bu bölümü yalnızca T3'ün kullandığı FAT32 düzeninde
okuyabiliyor; standart `mkfs.vfat` ayarlarıyla açılmıyor (§3.5, §12 #20).

**U-Boot kernel'i nasıl yüklüyor?** T3'ün U-Boot ayarlarında (`u-boot/board/t3/t3-gem-o1/t3-gem-o1.env`)
açılış komutu sırasıyla şunları yapar:

1. `envboot`: `uEnv.txt`'yi okur, içindeki değişkenleri kendi ayarlarının üzerine yazar.
   (Okuduktan hemen sonra `uenvcmd`'yi siler; bu yüzden o yöntem çalışmaz, §12 #19.)
2. `bootcmd_mmc` = `run args_mmc; run boot_mmc`. Bu iki değişken bizim `uEnv.txt`'mizde yeniden
   tanımlı:
   - `args_mmc`: Ethernet'e "buradayım" sinyali (`ping 10.42.0.11`), sonra Linux komut satırı:
     `root=/dev/mmcblk1p2 rootfstype=btrfs rootwait …`
   - `boot_mmc`: `Image`, DTB ve initramfs'i yükler, `booti` ile Linux'u başlatır. Başaramazsa
     `ping 10.42.0.99` ile hatayı bildirir.

`uEnv.txt`'nin tamamı (lite, `-own`):

```
firstboot=1
overlays=
ipaddr=10.42.0.12
netmask=255.255.255.0
serverip=10.42.0.11
optargs=earlycon=ns16550a,mmio32,0x02800000 console=tty1 quiet loglevel=3
args_mmc=echo uEnv: beacon to 10.42.0.11; ping 10.42.0.11; setenv bootargs console=${console} ${optargs} root=/dev/mmcblk${mmcdev}p2 rw rootfstype=btrfs rootwait roottimeout=30 bootpart=/dev/mmcblk${mmcdev}p1 firstboot=${firstboot} init_fatal_sh=1
boot_mmc=run get_kern_mmc; run get_fdt_mmc; run get_initrd_mmc; booti ${loadaddr} ${initrdaddr}:${filesize} ${fdtaddr}; echo booti failed; ping 10.42.0.99
```

`firstboot`, `bootpart`, `init_fatal_sh` T3 initramfs'i içindir; bizim initramfs'imiz bunları
yok sayar (bölümü `gemstone-growroot` servisi büyütür). `full` sürümde `quiet loglevel=3` yoktur.

**Overlay (kamera, DSI ekran, PWM, SPI, ek UART) kullanımı:** `uEnv.txt`'de `overlays=` satırına
dosya adlarını yazın ve `boot_mmc` satırına `run get_fdt_mmc;` sonrasına `run get_overlays;` ekleyin
(T3'ün kendi `boot_mmc`'sinde bu adım vardır, bizimkinde şimdilik yok). Örnek:

```
overlays=k3-am67a-t3-gem-o1-csi0-imx219.dtbo
boot_mmc=run get_kern_mmc; run get_fdt_mmc; run get_overlays; run get_initrd_mmc; booti …
```

### 10.1 T3'ün boot zinciriyle karşılaştırma ve imaj türleri

T3'ün resmi imajı (`gemstone-desktop-v2026.1-ubuntu-jammy`) karta yazılınca kart sorunsuz açıldı;
o kartın BOOT bölümü incelenerek yukarıdaki düzen bulundu (dosyalar `~/gemstone/vendor-boot/`;
Wi-Fi ve şifre bilgisi içeren `config.ini` kopyalanmadı).

| | T3 resmi imajı | Bizim imajımız (`-own`) |
|---|---|---|
| U-Boot | 2025.04-rc3-00025-gb8410d78120e | Aynı commit, kendimiz derledik |
| `tispl.bin` | TF-A v2.13.0, OP-TEE 693 KiB (1,2 MB) | TF-A v2.12.4 (lts), OP-TEE 4.6.0 (980 KB) |
| initramfs | T3'ün BusyBox initramfs'i (Yocto): USB seri, ilk açılışta bölüm büyütme | Debian `initramfs-tools` + `gemstone-growroot` servisi |
| Kernel | `6.12.24-ti`, PREEMPT_RT | `6.12.24-t3-gem-o1+`, aynı kaynak, PREEMPT_RT |
| Sistem | Ubuntu 22.04 | Pardus 25 |
| `uEnv.txt` yöntemi | `args_mmc` + `boot_mmc` | Aynı yöntem |

Hata ayıklama sırasında parçaları tek tek değiştirmek için ara imaj türleri kullanıldı
(`-vboot`: T3 bootloader + T3 initramfs, `-ownbl`: bizim bootloader + T3 initramfs, `-own`: hepsi
bizim). Üçü de kartta açıldı; önerilen `-own` (§18.5).
---

## 11. Tasarım kararları ve gerekçeleri

| Karar | Alternatif | Neden bu seçildi |
|---|---|---|
| T3'ün U-Boot/Linux fork'ları | BeagleY-AI depolarını alıp Gemstone desteğini kendimiz eklemek | Kart desteği (DDR ayarları, pinmux, DTS, defconfig) T3 tarafından zaten yazılmış ve bakımı yapılıyor. Kendimiz yazsak DDR ayarı gibi riskli işleri tekrar etmiş olurduk. |
| kernel.org GCC 11.5 (nolibc) | Dağıtımın `gcc-aarch64-linux-gnu` paketi | BeagleY-AI build betikleriyle birebir aynı derleyici. Host dağıtımından bağımsız ve tekrarlanabilir. |
| Debian 13 trixie | Debian 12 bookworm | Güncel kararlı sürüm, daha yeni Mesa/GStreamer/XFCE. `SUITE=bookworm` ile değiştirilebilir. |
| Kernel `.deb` paketi olarak | Dosyaları elle kopyalamak | Modüller `/lib/modules` altına doğru yerleşir, `dpkg` kayıtlıdır, ileride paketle güncellenebilir. |
| btrfs kök dosya sistemi | ext4 | T3'ün kendi U-Boot ortamı (`t3-gem-o1.env`) btrfs root bekliyor; uyumlu kalındı. zstd sıkıştırma SD kartta yer ve yazma ömrü kazandırır, anlık görüntü (snapshot) imkânı verir. |
| extlinux (U-Boot bootstd), `uEnv.txt` ile devreye alınıyor; T3'ün `bootcmd_mmc` yolu yedek | Yalnızca T3'ün sabit `bootcmd_mmc` yolu | U-Boot'un standart, dağıtımlarca desteklenen yöntemi. Kernel, DTB, overlay ve kernel parametreleri tek okunabilir dosyada. U-Boot'u yeniden derlemeden `uEnv.txt` ile seçiliyor; çalışmazsa vendor yolu da hazır (§10). |
| initramfs gzip | Debian varsayılanı zstd | U-Boot ve kernel tarafında en geniş uyumluluk. Boyut farkı küçük. |
| `debian`/`temppwd` + zorunlu şifre değişimi | Şifresiz veya sabit şifre | BeagleBoard alışkanlığı, ama güvenlik için ilk girişte değiştirme zorunlu. |
| SSH host anahtarları ilk açılışta | İmajda sabit anahtar | Aynı imajdan çıkan kartların aynı kimliği paylaşmaması için. |
| XFCE masaüstü ("full") | Sadece konsol ("minimal") | "Full" hedef istendi. BeagleY-AI'nin XFCE imajının karşılığı. |
| 8 GB imaj | Daha büyük | Küçük imaj daha hızlı yazılır. İlk açılıştan sonra btrfs bölümü kart boyutuna büyütülebilir (bkz. §14). |

---

## 12. Karşılaşılan sorunlar ve çözümleri

| # | Sorun | Teşhis | Çözüm |
|---|---|---|---|
| 1 | İlk U-Boot denemesi `ModuleNotFoundError: No module named 'setuptools'` ile durdu | `scripts/dtc/pylibfdt` Python bağlaması setuptools istiyor | `python3-setuptools` ve `swig` kuruldu |
| 2 | Derleme makinesine SSH ile bağlanılamadı | `openssh-server` kurulu değildi | `openssh-server` kuruldu (uzaktan yönetim için) |
| 3 | Otomatik komut girişinde karakterler bozuldu (`install` → `ınstall`) | Otomasyonun gönderdiği tarama kodları klavye düzeniyle uyuşmuyordu | Otomasyon süresince klavye düzeni `us` yapıldı |
| 4 | Kernel + debootstrap aynı anda çalışırken derleme makinesi dondu | Yeterli boş RAM kalmamıştı (özellikle sanal makinede host belleği diske taşıyınca) | Derleme makinesine yeterli RAM ayrıldı; 4 GB / 4 vCPU ile sorunsuz |
| 5 | Sanal makine yoğun derlemede ikinci kez kilitlendi | Tam donanım sanallaştırması kapalıyken (yazılım/NEM katmanı) çok vCPU'lu yükte misafir yanıt vermiyor | vCPU düşürüldü; kalıcı çözüm host'ta donanım sanallaştırmasını (VT-x/AMD-V) açmak (§14) |
| 6 | Kernel bağlama hatası: `undefined reference to 'func_table'`, `dangerous relocation` | Çökmelerde yarım yazılmış nesne dosyaları | Boş `.o` dosyaları silindi, ardından `make clean` ve temiz derleme |
| 7 | debootstrap: `Cannot check Release signature` | Host'ta `debian-archive-keyring` yok | Uyarı. İmzalar doğrulanmadan indirildi. Paket listeye eklendi, sonraki build'lerde doğrulanır |
| 8 | Host'ta `mkfs.btrfs` yoktu | İlk paket listesinde `btrfs-progs` eksikti | Kuruldu. `03-rootfs-image.sh` artık eksik araçları en başta kendisi kuruyor |
| 9 | debootstrap: `debian-archive-keyring.gpg may be incorrect or out of date` | Derleme makinesindeki Debian anahtarlığı eski olabilir ve trixie imza anahtarlarını içermeyebilir | 03 betiği Debian'dan güncel `debian-archive-keyring_2025.1_all.deb` paketini indirip yalnızca debootstrap için kullanıyor; host sistemine dokunulmuyor |
| 10 | Bootloader/kernel betikleri `build/` altına yazamadı | `build/` silinince 03 betiği (root) onu root sahipliğiyle yeniden oluşturdu | Normal kullanıcı adımları ayrı bir dizine (`build-user/`) taşındı; root ve kullanıcı çıktıları artık karışmıyor |
| 11 | Kernel paketleme: `No rule to make target '…/k3-am67a-t3-gem-o1-pinmux.dtsi', needed by '__dtbs_install'` | T3 kernel ağacının `arch/arm64/boot/dts/ti/Makefile` dosyasında bir `.dtsi` (include dosyası) yanlışlıkla `dtb-` listesine eklenmiş; derleme geçiyor ama `dtbs_install` ve `bindeb-pkg` kırılıyor | O satır silindi. Yama `patches/linux-0001-…patch` olarak saklandı. **T3'e upstream hata bildirimi olarak gönderilmeli** |
| 12 | Kernel sürümü `6.12.24-t3-gem-o1+` (sonda `+`) | Kaynak ağaçta commit'lenmemiş değişiklik var (11 numaralı yama), kernel bunu `+` ile işaretliyor | Bilgi amaçlı. Yama T3 deposuna girince `+` kaybolur |
| 13 | apt/sqv: imza `Not live until …` | Derleme makinesinin saati geride | 03 betiği saati aynanın HTTP `Date` başlığıyla karşılaştırıp 5 dakikadan fazla sapma varsa düzeltiyor |
| 14 | `E: Unable to locate package python3-gpiod` | trixie'de paketin adı `python3-libgpiod` | Ad düzeltildi. Kurulum fonksiyonu (`inst`) artık depoda olmayan paketleri uyarıyla atlıyor, build'i durdurmuyor |
| 15 | Yeniden çalıştırmada `/etc/resolv.conf: No such file or directory` | systemd-resolved kurulunca `resolv.conf`, `/run` altına sembolik bağ oluyor; chroot'ta hedef yok | Build sırasında gerçek dosya yazılıyor, sonunda bağ yeniden kuruluyor. Aşama 2 bitince `.stage2-done` işareti konuyor, yeniden çalıştırmada atlanıyor |
| 16 | **Kart açılmadı, HDMI boş** | T3 U-Boot'u extlinux kullanmıyor; `bootcmd_mmc` `gemstone-image-rd-t3-gem-o1.cpio.gz` arıyor, bulamayınca kernel'e bozuk initrd veriyor. U-Boot'ta görüntü desteği yok, HDMI ancak kernel açılınca gelir (SiI9022 köprüsü, `DRM_TIDSS=y`, `DRM_SII902X=y`) | BOOT bölümüne `uEnv.txt` (extlinux'a yönlendirme) ve initrd'nin vendor adıyla kopyası eklendi (§10). **Kartta henüz doğrulanmadı**; seri konsol çıktısıyla teyit edilmeli |
| 17 | Pardus: `xfce4 : Depends: xfdesktop4 … but it is not installable` | Pardus `yirmibes` deposunda arch:all `xfdesktop4-data 4.20.1-1pardus2` var, ama arm64 için yalnızca Debian'ın `xfdesktop4 4.20.1-1` paketi var ve tam sürüm eşleşmesi istiyor | `xfdesktop4-data` `yirmibes-deb` sürümüne sabitlendi (`/etc/apt/preferences.d/arm64-xfdesktop`). apt 3'ün yeni çözücüsü başarısız olursa `--solver internal` ile tekrar deneniyor |
| 18 | Pardus imajında `/etc/os-release` hâlâ "Debian GNU/Linux 13" | Pardus'un `base-files 13.8+pardus25.2.1` paketi yeni bir bağımlılık getiriyor; `apt-get upgrade` yeni paket kurmadığı için onu "kept back" bıraktı | `apt-get full-upgrade` kullanılıyor. Eski betikle kurulmuş rootfs'te betik bunu algılayıp yalnızca bu adımı çalıştırıyor |
| 19 | `uEnv.txt` düzeltmesi (#16) de işe yaramazdı | T3'ün `importbootenv` komutu `uenvcmd`'yi içeri aldıktan hemen sonra siliyor (`setenv uenvcmd`). Ayrıca kendi `tispl.bin`'imiz (TF-A 2.12.4, OP-TEE) T3'ünkinden farklı | T3'ün çalışan kartı incelendi. `-vboot` imajında T3'ün bootloader'ı, initramfs'i ve `args_mmc`/`boot_mmc` düzeni kullanılıyor (§10.1) |
| 20 | `-vboot` kartı da hiç açılmadı: ARP yok, LED yok, HDMI yok. Kartta `firstboot=1` değişmemiş, p2 büyümemiş, yani kernele bile gelinmemiş | Bootloader dosyaları T3'ünkiyle birebir aynıydı; farklı olan BOOT bölümünün FAT32 biçimiydi. T3: 128 MiB, küme başına 1 sektör, gizli sektör 0, geometri 16/32. Bizde mkfs.vfat varsayılanları vardı: 512 MiB, 8 sektör/küme, gizli 2048, 255/63. AM67A ROM'u `tiboot3.bin`'i kendi küçük FAT sürücüsüyle okuyor | `03-rootfs-image.sh` artık T3 düzeniyle yazıyor: `parted … 1MiB 129MiB` ve `mkfs.vfat -F 32 -s 1 -h 0 -g 16/32`. Boot sektörü alanları T3 imajıyla karşılaştırıldı, hepsi aynı. **Kartta doğrulanması bekleniyor** |

---

## 13. SD karta yazma ve kartta test

### 13.1 Yazma

**balenaEtcher / Raspberry Pi Imager:** `out/…img.xz` dosyasını başka bir bilgisayara kopyalayıp
**balenaEtcher** ya da **Raspberry Pi Imager** ("Use custom") ile de yazabilirsiniz.

**Linux (önerilen):** `scripts/04-flash-sd.sh` en yeni imajı yazar ve doğrular. Güvenlik
kontrolleri var: yalnızca USB/MMC veya çıkarılabilir disk, en fazla 256 GB, kök diski değil,
imajdan büyük. Yazdıktan sonra kartı geri okuyup sha256 karşılaştırır (`VERIFY_OK`, `FLASH_OK`).
Belirli bir imaj için `IMG=/yol/imaj.img` verilebilir.

```bash
lsblk                                   # kartın adını bulun (ör. /dev/sdb)
sudo ./scripts/04-flash-sd.sh /dev/sdb
```

**Elle:**
```bash
xzcat t3-gem-o1-*-arm64-full-*.img.xz | sudo dd of=/dev/sdX bs=4M status=progress conv=fsync
```

### 13.2 İlk açılış

1. Kartın boot modu anahtarlarını **SD kart (MMC1)** konumuna getirin.
2. USB-UART dönüştürücüyü `UART0` (Linux'ta `ttyS2`) pinlerine bağlayın: 115200 8N1.
3. Güç verin. Konsolda sırayla şunlar görünmeli:
   `U-Boot SPL 2025.04…` (R5) → `U-Boot SPL` (A53) → `U-Boot 2025.04…` → `Loaded env from uEnv.txt`
   → `uEnv: beacon to 10.42.0.11` → kernel mesajları → (ilk açılışta) `Expanding root partition…`
   → `gemstone login:`
4. `debian` / `temppwd` (Pardus imajında `pardus` / `temppwd`) ile girin; yeni şifre istenecek.
5. **IP adresi (sabit):** Kart **10.42.0.12/24** (ağ geçidi 10.42.0.1, DNS 1.1.1.1 / 8.8.8.8).
   Bu, T3'ün kendi U-Boot ortamındaki adres düzeni (`ipaddr=10.42.0.12`, `serverip=10.42.0.11`).
   Bilgisayarın Ethernet adaptörüne **10.42.0.11 / 255.255.255.0** verip `ssh pardus@10.42.0.12`
   ile bağlanılır. Ayar NetworkManager profili olarak
   `/etc/NetworkManager/system-connections/wired-static.nmconnection` dosyasında; DHCP'ye dönmek için
   `nmcli con mod wired-static ipv4.method auto ipv4.addresses "" ipv4.gateway ""`.
   Betikte `NET_IP`, `NET_GW`, `NET_PC` ile değiştirilebilir.
   Wi-Fi için: `nmcli dev wifi connect "AĞ" password "ŞİFRE"`.

### 13.2.1 Seri konsol olmadan açılışı izleme (Wireshark)

İmaj, açılışın her aşamasında Ethernet'ten tanınabilir bir paket gönderir. Wireshark'ta
`arp or icmp` filtresiyle bakın. ARP istekleri yayın olduğu için PC'nin IP'si farklı olsa da görünür.

| Görülen paket | Anlamı | Kaynağı |
|---|---|---|
| Hiçbir şey | U-Boot'a ulaşılamadı: ROM/SPL aşaması (switch, silikon tipi, kart) | — |
| `Who has 10.42.0.11? Tell 10.42.0.12` (bir kez) | U-Boot çalışıyor, `uEnv.txt` okundu | `uEnv.txt` → `ping` |
| `Who has 10.42.0.99? Tell 10.42.0.12` | Kernel başlatılamadı (`booti` hatası; `-vboot` imajında) | `uEnv.txt` → `boot_mmc` |
| 5 sn'de bir `10.42.0.12 → 10.42.0.11` | Linux tamamen açıldı, ağ çalışıyor | `gemstone-beacon.service` |

Ayrıca kernel mesajları HDMI'ye de basılır (`console=tty1`), Linux açıkken yeşil ACT LED'i
kalp atışı ritminde yanıp söner. İşaret servisini kapatmak için:
`sudo systemctl disable --now gemstone-beacon`.

**Hiç çıktı yoksa:** ROM `tiboot3.bin` dosyasını okuyamamıştır. Boot modu anahtarlarına, kartın
MBR + FAT32 ilk bölümüne ve silikon tipine bakın: imaj HS-FS içindir (`tiboot3-j722s-hs-fs-evm.bin`);
HS-SE kart için `tiboot3-j722s-hs-evm.bin` kullanılmalı.
**U-Boot çıktısı var ama kernel açılmıyorsa:** U-Boot'ta boşlukla otomatik açılışı durdurup
`printenv bootdev mmcdev`, `ls mmc 1:1`, `bootflow scan -l mmc1` komutlarına bakın.

### 13.3 Kontrol listesi (kartta yapılacak)

| Test | Komut | Beklenen |
|---|---|---|
| Kernel | `uname -a` | `6.12.24-…-t3-gem-o1 … aarch64` |
| Bellek | `free -h` | Kartın DDR kapasitesi |
| Kök FS | `findmnt /` | `btrfs`, `LABEL=rootfs` |
| Ethernet | `ip a`, `ping 10.42.0.11` | `10.42.0.12/24` atanmış, PC'ye ping gidiyor |
| Wi-Fi | `nmcli dev wifi list` | RTL8822CS ağları listeliyor |
| Bluetooth | `bluetoothctl list` | Denetleyici görünüyor |
| USB / PCIe | `lsusb`, `lspci` | Aygıtlar listeleniyor |
| GPIO / I2C | `gpiodetect`, `i2cdetect -l` | Denetleyiciler listeleniyor |
| Masaüstü | HDMI/DSI ekran | lightdm giriş ekranı → XFCE |
| Kamera (overlay ile) | `v4l2-ctl --list-devices` | CSI kamera görünüyor |

### 13.4 Test sonuçları (`-own` imajı, 2026-11-15)

Kartta tek komutla toplanan rapor (yalnızca okur, hiçbir ayarı değiştirmez; çıktı `~/kart-rapor.txt`):

```bash
{ echo "== sistem"; uname -r; head -2 /etc/os-release; df -h / | tail -1; systemctl is-active gemstone-growroot; ls /var/lib/gemstone/
  echo "== ag"; ip -br addr
  echo "== wifi"; nmcli -t dev | grep -i wifi; nmcli -t -f SSID dev wifi list | head -5
  echo "== bluetooth"; bluetoothctl list; rfkill list
  echo "== usb"; lsusb
  echo "== pcie/m2"; lspci; lsblk -d -o NAME,SIZE,TRAN,MODEL
  echo "== i2c"; ls /dev/i2c-*; for d in /sys/bus/iio/devices/*/name; do cat $d; done
  echo "== can"; ip -br link | grep -i can
  echo "== gpu/tee"; ls /dev/dri /dev/tee*
  echo "== hatalar"; systemctl --failed --no-legend; dmesg --level=err,warn | tail -25
} > ~/kart-rapor.txt 2>&1
```

| Donanım | Sonuç | Kanıt / not |
|---|---|---|
| Kernel, Pardus | ✅ | `6.12.24-t3-gem-o1+`, `Pardus GNU/Linux 25 (yirmibes)` |
| **Bölüm büyütme** (`gemstone-growroot`) | ✅ | `/dev/mmcblk1p2 30G`, `growroot.done` var, servis bir kez çalışıp bitti |
| Başarısız servis | ✅ yok | `systemctl --failed` boş |
| Ethernet | ✅ | `eth0 UP 10.42.0.12/24` |
| Wi-Fi (RTL8822CS) | ✅ tarama | `wlan0` var, çevredeki ağlar (5 GHz dahil) listeleniyor. Bir ağa bağlanma denenmedi |
| Bluetooth | ✅ denetleyici | `hci0` açık, engel yok. Cihaz eşleştirme denenmedi |
| USB | ✅ | TUSB8041 hub (USB 2 ve 3 tarafı) ve takılan Logitech alıcı görünüyor. Uyarı: `onboard-usb-dev 2-1: can't set config #1, error -71`; hub'ın USB 3 tarafının ayarı başarısız olmuş olabilir, USB 3 bir bellekle hız denenmeli |
| PCIe / M.2 | ✅ denetleyici | `00:00.0 PCI bridge: Texas Instruments b010` (kök köprü). Yuvada SSD olmadığı için aygıt yok. `of_irq_parse_pci … rc=-22` uyarısı köprü için zararsız |
| eMMC | ✅ | `mmcblk0 28,9G` + `boot0/boot1` bölümleri (eMMC'ye kurulum için gerekli) |
| I2C | ✅ | `/dev/i2c-1` … `i2c-6` |
| Nem/sıcaklık (HDC2010) | ✅ | IIO aygıtı `hdc2010` |
| IMU (ICM-20948), barometre (LPS22DF) | ❓ | IIO'da görünmüyor; DTS'te bunlar sürücüsüz SPI aygıtı (`spidev`) olarak tanımlı, kullanıcı programı okumalı (§17.5) |
| CAN | ✅ arayüz | `can0` var (kapalı). Kullanmak için: `sudo ip link set can0 up type can bitrate 500000` |
| **OP-TEE** | ✅ | `/dev/tee0`, `/dev/teepriv0`: güvenli dünya çalışıyor ve Linux onunla konuşabiliyor (§18.3) |
| Ekran (DRM) | ✅ | `/dev/dri/card0` (tidss ekran denetleyicisi) |
| GPU (PowerVR) | ❌ beklenen | `renderD*` yok: `DRM_POWERVR` kapalı (§14) |
| RTC | ⚠️ | `rtc-ds1307 2-0068: unable to read the hardware clock`: harici RTC'de saat ayarlı değil ya da pil yok. Saat ağdan alındıktan sonra `sudo hwclock -w` ile yazılabilir |
| C7x DSP / MMA (yapay zekâ), R5F çekirdekleri | ❌ firmware yok | `remoteproc… j722s-c71_0-fw … error -2`: hızlandırıcıların firmware dosyaları rootfs'te yok. TI'ın `ti-linux-firmware` / EdgeAI paketlerinden `/lib/firmware`'a konmalı |

Zararsız uyarılar (bilgi için): `ITS … Devices Table too large`, `SPI driver tps6594 has no
spi_device_id`, `sdhci-am654 … voltages below defined range`, `bpf-restrict-fs: Failed to load
BPF object` (kernel'de BPF LSM kapalı), `rtc-ti-k3 … Clock rate 32552`.

---

## 14. Açık konular ve sonraki adımlar

1. **Kartta ayrıntılı test:** ✅ 2026-11-15 temel test yapıldı, sonuçlar §13.4. Kalanlar: Wi-Fi'ye
   bağlanma, BT eşleştirme, USB 3 hızı, M.2 SSD, kamera/DSI overlay'leri, IMU/barometre okuma,
   C7x/R5F firmware'leri, RTC saati.
2. **Kök bölümü büyütme:** `-vboot` imajında T3 initramfs'i ilk açılışta (`firstboot=1`) bunu yapıyor.
3. **Bootloader'ı tamamen kendimiz derlemek:** ✅ **2026-11-15 tamamlandı.** `-ownbl` imajı
   (`out/…-20261115-ownbl.img`, sha256 `b65695ea…`) kendi `tiboot3.bin`, `tispl.bin` ve
   `u-boot.img` dosyalarımızla (`01-bootloader.sh`) kartta giriş ekranına kadar açıldı. Yani asıl
   sorun bootloader değil, FAT düzeni ve `uenvcmd` idi (§12 #19, #20). Üretmek için:
   `touch ~/gemstone/.own-bl && sudo ./go-pardus` (sudo ortam değişkenlerini sildiği için
   `OWN_BL=1` yerine işaret dosyası; derlemeden sonra `rm ~/gemstone/.own-bl`).
   Aynı gün initramfs de bizimkiyle (Debian `initramfs-tools`) değiştirildi; ilk açılıştaki
   bölüm büyütmeyi `gemstone-growroot.service` yapıyor. **`-own` imajı kartta açıldı.**
   `vendor-boot/` artık yalnızca `03`'ün `uEnv.txt` düzenini seçmesi için bir işaret olarak
   aranıyor (`tispl.bin` varlığı); içindeki dosyalar `-own` imajına girmiyor. Temizlik işi:
   `03`'ü `vendor-boot/` olmadan da T3 `uEnv.txt` düzenini kullanacak hale getirmek.
4. **eMMC'ye kurulum:** Şimdilik SD kart hedefleniyor. eMMC için `tiboot3.bin` eMMC boot0
   bölümüne yazılmalı ve U-Boot ortamı (`mmcdev=0`) uyarlanmalı. T3'ün env dosyasında
   `flash_emmc_*` komutları örnek olarak duruyor.
5. **Build makinesi performansı:** Sanal makinede tam donanım sanallaştırması (VT-x/AMD-V) açıkken
   derleme tam hızda çalışır ve 8–12 vCPU güvenle kullanılabilir. En hızlı seçenek fiziksel bir
   Linux (Pardus 25) derleme makinesidir.
6. **AI hızlandırıcı / GPU:** ✅ GPU (Vulkan, Mesa 26) ve C7x DSP'lerin açılması 18 Kasım'da
   tamamlandı (§23). Kalan: C7x'te gerçek yapay zekâ firmware'i ve TI'ın kullanıcı alanı
   kitaplıkları (TIDL / EdgeAI; şu an DSP'lerde TI'ın deneme firmware'i çalışıyor), masaüstünün
   GPU ile çizilmesi (§23.3).
7. **Secure boot:** HS-SE silikon veya imzalı açılış gerekirse TI anahtar akışıyla imzalama yapılmalı.
8. **CI:** Üç betik parametrik ve sıralı. Bir CI sunucusunda (ör. GitLab runner, Debian 13 / Pardus 25)
   doğrudan çalıştırılabilir.
9. **Debian çekirdeğinde kalanlar** (ayrıntı §21.7): Ethernet `rgmii-id` ayarının kartta denenmesi,
   HDMI ses saatinin (PPM) düzeltilmesi.
10. **TI çekirdeği seçeneği:** Dört çekirdek seçeneğinden (T3, Debian, mainline, TI) TI'ın resmi
    kaynağı henüz hazırlanmadı (`KERNEL=ti` yeri `03`'te hazır).
11. **`apt upgrade` ile çekirdek güncellemesi:** Kendi apt depomuz gerekiyor (§22.7). Yeri henüz
    belirlenmedi.
12. **Ekran koruyucudan sonra görüntü gelmiyor** (Debian çekirdeği, masaüstü): ekran karardıktan
    sonra fare/klavyeyle arka ışık hafifçe canlanıyor ama görüntü gelmiyor. Çekirdek bağlantıyı
    açık gösteriyor, hata yazmıyor. Masaüstü açıkken `xset dpms force off/on` ve
    `xrandr --output … --off/--auto` ile denenmeli. Geçici çözüm: XFCE Güç Yöneticisi'nde ekran
    karartmayı ve DPMS'i kapatmak.
13. ~~Mainline çekirdek ve `minimal` imaj kartta denenmedi~~ ✅ 22 Kasım: 7.3.5 ve 6.18 LTS ile
    kartta açıldı (§24.5). Kalan: ekransız imajda Wi-Fi bağlantısı, BT, CAN ve sensörlerin ayrıca
    denenmesi; `KASLR` için U-Boot'un çekirdeğe tohum vermesi.
14. **Mainline'a geçiş takibi:** HDMI yamaları ana Linux'a girince `debian` ve `mainline`
    seçenekleri birleşir; o zaman masaüstü de yamasız çekirdekle çalışır (§24.6).

---

## 15. Hızlı başvuru: tüm build tek seferde

```bash
cd ~/gemstone
./scripts/01-bootloader.sh            2>&1 | tee out-bootloader.log   # ~3 dk
JOBS=4 ./scripts/02-kernel.sh         2>&1 | tee out-kernel.log       # ~45–60 dk
sudo ./scripts/03-rootfs-image.sh     2>&1 | tee out-rootfs.log       # ~30–60 dk (Debian 13)
sudo DISTRO=pardus ./scripts/03-rootfs-image.sh 2>&1 | tee out-pardus.log   # Pardus 25 (kısa yol: sudo ./go-pardus)
ls -la out/                                                           # imajlar burada
sudo ./scripts/04-flash-sd.sh /dev/sdX                                # en yeni imajı karta yaz + doğrula
```

### Pardus 25 varyantı (`DISTRO=pardus`)

Pardus 25 "yirmibes" Debian 13 tabanlı ve resmi deposunda arm64 var. Bootloader ve kernel
aynı kalır, yalnızca kök dosya sistemi değişir:

| | Debian | Pardus |
|---|---|---|
| debootstrap kaynağı | `deb.debian.org/debian trixie` | `depo.pardus.org.tr/pardus yirmibes-deb` (Debian 13'ün Pardus aynası) |
| Ek depolar | `trixie-updates`, `trixie-security` | `pardus yirmibes` (Pardus paketleri), `guvenlik yirmibes-deb` |
| Anahtar | `debian-archive-keyring` (güncel, indirilir) | `pardus-archive-keyring` (güncel, indirilir; 3 deponun imzası doğrulandı) |
| Masaüstü | `task-xfce-desktop`, PulseAudio | `pardus-xfce-desktop` (önerilerle), PipeWire |
| Engellenenler | — | `grub*`, `*-grub-theme`, `plymouth*`, `pardus-installer*`, `os-prober` (kart U-Boot ile açılıyor) |
| Dil / klavye | `en_US.UTF-8`, `us` | `tr_TR.UTF-8`, `tr` |
| Kullanıcı | `debian` / `temppwd` | `pardus` / `temppwd` |
| İmaj boyutu | 8 GB | 12 GB |

> **Not:** Pardus, arm64 için kurulum imajı ve resmi destek sunmuyor. pardus.org.tr'deki
> indirmeler yalnızca amd64. Pardus'un depoları ise arm64'ü resmen yayımlıyor
> (`InRelease`: `Architectures: amd64 arm64 i386`). Bu sistem, Pardus deposunun arm64 bölümüyle
> kurulmuş, **resmî olmayan bir Pardus 25.2 türevidir**:
> - `yirmibes` deposunun arm64 listesinde yalnızca 273 mimariden bağımsız (`all`) Pardus paketi var.
>   amd64'te bunlara ek olarak 232 Pardus derlemesi paket bulunuyor.
> - Pardus'un yalnızca amd64 için yamalayıp derlediği 12 paket bu sistemde Debian 13 sürümüyle kurulu:
>   `xfce4-session`, `xfdesktop4`, `xfce4-goodies`, `xorg`, `xserver-xorg*`, `bash`, `python3-apt`,
>   PackageKit kitaplıkları, `gnome-system-tools`. TSV'nin `not` sütununda Pardus sürümüyle birlikte işaretli.
> - Bu yüzden Pardus'un amd64'e özel küçük yamaları (ör. masaüstü varsayılanları) arm64'te bulunmayabilir.

**Kurulu paketler** (rootfs 8 Kasım 2026, tam liste: [`pardus-yirmibes-paketler.tsv`](pardus-yirmibes-paketler.tsv), README ile aynı klasörde;
sütunlar: paket, sürüm, mimari, depo, not):

| Depo | Paket | Not |
|---|---|---|
| `http://depo.pardus.org.tr/pardus` `yirmibes` | 33 | Pardus'a özel paketlerin hepsi `all` (mimariden bağımsız: betik, tema, Python araçları). Örnekler: `base-files 13.8+pardus25.2.1` (sürüm 25.2), `pardus-xfce-desktop 2025.0.1`, `pardus-lightdm-greeter 0.4.16`, `pardus-software 1.0.7`, `pardus-update 0.7.0` |
| `http://depo.pardus.org.tr/pardus` `yirmibes-deb` | 1527 | Debian 13'ün arm64 ikilileri, Pardus aynasından |
| `http://depo.pardus.org.tr/guvenlik` `yirmibes-deb` | 225 | Güvenlik güncellemeleri (ör. `firefox-esr 153.6.0esr`, `libreoffice-core 25.2.3`, `xserver-xorg-core 21.1.16`, `apt 3.0.4`) |
| Bizim derleme | 1 | `linux-image-6.12.24-t3-gem-o1+ 1gemstone` (arm64) |

Toplam 1786 paket: 1398 `arm64`, 388 `all`. **arm64 için derlenmiş her ikili Debian 13'ten**
geliyor; Pardus'un katkısı mimariden bağımsız paketler. Bu yüzden Pardus x86 dışında da
sorunsuz kuruluyor. Önemli sürümler: `libc6 2.41-12+deb13u4`, `systemd 257.13`, XFCE 4.20
(`xfce4-session 4.20.2`, `xfwm4 4.20.0`), `mesa 25.0.7`, `network-manager 1.52.1`,
`pipewire 1.4.2`, `python3 3.13.5`, `gcc 14.2.0`, `openssh 10.0p1`.

Liste yeniden üretmek için derleme makinesinde: `dpkg-query --admindir=build/rootfs-pardus-yirmibes/var/lib/dpkg -W`,
kartta: `dpkg -l` ve `apt-cache policy <paket>`.

Temiz derleme (her şeyi sıfırdan). `build/` root'a ait olduğu için `sudo` gerekir:

```bash
rm -rf ~/gemstone/build-user ~/gemstone/out
sudo rm -rf ~/gemstone/build
```

> Uyarı: Rootfs betiği çalışırken `build/` silinmemeli. Betik chroot içine `/dev`, `/proc`
> ve `/sys` bağlıyor; önce betiğin bitmesini ya da durmasını bekleyin.

---

## 16. Kaynak haritası ve değişiklik rehberi

Bu bölüm, karttaki her baytın nereden geldiğini ve bir şeyi değiştirmek için hangi dosyaya
dokunulacağını gösterir. Yollar `~/gemstone/` altına göredir.

### 16.1 SD karttaki her dosya nereden geliyor

```
SD kart
├── p1 BOOT (FAT32, 128 MiB)
│   ├── tiboot3.bin ─────────┐  -vboot: vendor-boot/ (T3'ün resmi imajı)
│   ├── tispl.bin  ──────────┤  kendi zincir: scripts/01-bootloader.sh → out/boot/
│   ├── u-boot.img ──────────┘
│   ├── gemstone-image-rd-t3-gem-o1.cpio.gz   -vboot: vendor-boot/ (T3 initramfs)
│   ├── Image, k3-am67a-t3-gem-o1.dtb, overlays/*.dtbo   scripts/02-kernel.sh → out/boot/
│   ├── initrd.img            rootfs içinde update-initramfs (Debian initramfs-tools)
│   ├── uEnv.txt              scripts/03-rootfs-image.sh ("3. boot partition content")
│   └── extlinux/extlinux.conf    scripts/03-rootfs-image.sh (bu U-Boot'ta kullanılmıyor)
└── p2 rootfs (btrfs)         scripts/03-rootfs-image.sh: debootstrap + Pardus/Debian paketleri
                              + out/kernel/linux-image-*.deb + ağ/servis ayarları
```

### 16.2 Bileşen → kaynak → derleyen → çıktı

| Bileşen | Kaynak (VM yolu) | Üst depo, commit | Derleyen | Çıktı |
|---|---|---|---|---|
| R5 SPL (`tiboot3.bin`) | `u-boot/` | `t3gemstone/u-boot` `b8410d78120e` | `01-bootloader.sh` [3/4] | `out/boot/tiboot3.bin` (HS-FS), `tiboot3-j722s-hs-evm.bin` (HS-SE) |
| TIFS firmware (`tiboot3.bin` içinde) | `ti-linux-firmware/ti-sysfw/ti-fs-firmware-j722s-hs-fs-*.bin` | `beagleboard/ti-linux-firmware` `11.01.03` | binman, R5 derlemesi sırasında | **Kaynağı yok:** TI'ın imzalı ikilisi |
| Board yapılandırması (kaynak, güvenlik, güç) | `u-boot/board/t3/t3-gem-o1/{board,sec,pm,rm,tifs-rm}-cfg.yaml` | U-Boot ağacında | binman | `tiboot3.bin` içinde |
| DDR ayarları | `u-boot/arch/arm/dts/k3-am67a-t3-gem-o1-ddr-lp4.dtsi` | U-Boot ağacında | R5 SPL | `tiboot3.bin` içinde |
| TF-A (BL31) | `trusted-firmware-a/` | `lts-v2.12.4` `a9fcaf3` | `01-bootloader.sh` [1/4] `PLAT=k3 TARGET_BOARD=lite SPD=opteed` | `build-user/tfa/k3/lite/release/bl31.bin` → `tispl.bin` |
| OP-TEE (BL32) | `optee_os/` | `4.6.0` `7178564` | `01-bootloader.sh` [2/4] `PLATFORM=k3-am62x` | `build-user/optee/core/tee-pager_v2.bin` → `tispl.bin` |
| DM firmware (R5 üzerinde çalışır) | `ti-linux-firmware/ti-dm/j722s/` | `11.01.03` | binman | `tispl.bin` içinde. **Kaynağı TI'da**, burada ikili |
| A53 SPL + U-Boot | `u-boot/` (`configs/am67a_t3_gem_o1_a53_defconfig`, DTS: `dts/upstream/src/arm64/ti/k3-am67a-t3-gem-o1.dts` + `arch/arm/dts/k3-am67a-t3-gem-o1-u-boot.dtsi`) | `b8410d78120e` | `01-bootloader.sh` [4/4] | `tispl.bin`, `u-boot.img` |
| U-Boot varsayılan ortamı (`bootcmd`, `bootcmd_mmc`…) | `u-boot/board/t3/t3-gem-o1/t3-gem-o1.env` | U-Boot ağacında | A53 U-Boot | `u-boot.img` içinde |
| Kart algılama (`mmcdev`, `bootdev`) | `u-boot/board/t3/t3-gem-o1/t3-gem-o1.c` | U-Boot ağacında | A53 U-Boot | `u-boot.img` içinde |
| Kernel (`t3`) | `linux/` (`arch/arm64/configs/t3_gem_o1_defconfig`) | `t3gemstone/linux` `6267aeaee` + `patches/linux-0001-…pinmux…patch` | `02-kernel.sh` | `out/boot/Image`, `out/kernel/linux-image-*.deb` |
| Kernel (`debian`) | `kernels/debian/src` | Debian `linux 7.2.12-1~bpo13+1` + `kernels/debian/patches/` (24) | `kernels/debian/build.sh` | `kernels/debian/out/` |
| Kernel (`mainline`) | `kernels/mainline/src` | kernel.org `linux-6.18.64.tar.xz` (LTS), yamasız | `kernels/mainline/build.sh` | `kernels/mainline/out/` |
| Kart tanımı (`debian`, `mainline`) | `board/dts/` (common + display ya da gpu-v7.4) | bu proje | `board/dts/build-dtb.sh` (iki `build.sh` çağırır) | `kernels/<ad>/out/k3-am67a-t3-gem-o1.dtb` |
| Bütün sürüm numaraları | `versions.env` | — | `00`, `kernels/*/build.sh` okur | — |
| GPU firmware, C7x firmware | `ti-linux-firmware/powervr/`, `ti-linux-firmware/ti-ipc/j722s/` | `11.01.03` | `03` "2c" | rootfs `/usr/lib/firmware/` |
| Mesa 26 (masaüstlü boyutlar) | Debian `trixie-backports` | 26.1.6 | `03` "2c" | rootfs |
| Ana DTB | `linux/arch/arm64/boot/dts/ti/k3-am67a-t3-gem-o1.dts` (+ `-pinmux.dtsi`, `k3-j722s*.dtsi`) | aynı | `02-kernel.sh` (`make dtbs`) | `out/boot/k3-am67a-t3-gem-o1.dtb` |
| Overlay'ler | `linux/arch/arm64/boot/dts/ti/k3-am67a-t3-gem-o1-*.dtso` | aynı | `02-kernel.sh` | `out/boot/overlays/*.dtbo` |
| T3 initramfs (`-vboot`) | T3'ün Yocto derlemesi (BusyBox + `init.d/*` betikleri, GPL/MIT) | T3 v2026.1 imajından kopya | — | `vendor-boot/gemstone-image-rd-t3-gem-o1.cpio.gz` |
| Pardus/Debian paketleri | `depo.pardus.org.tr` / `deb.debian.org` | Pardus 25.2 / Debian 13 | `03-rootfs-image.sh` | `build/rootfs-pardus-yirmibes/` |
| Paket kaynak kodu | Kartta veya derleme makinesinde `deb-src` satırı + `apt source <paket>` | aynı depolar | — | — |
| Ağ, işaret servisi, uEnv, bölüm düzeni | `scripts/03-rootfs-image.sh` | bu proje | `03-rootfs-image.sh` | imaj |

`patches/linux-0001-dts-ti-do-not-list-pinmux-dtsi-as-dtb.patch`, T3 kernel ağacına uygulanan
tek yerel değişikliktir (§12 #11). `git -C linux diff` ile görülebilir. U-Boot, TF-A ve OP-TEE
ağaçlarında yerel değişiklik yoktur (`git status` temiz).

Kaynak paketleri indirmek için, örneğin kartta:

```bash
echo 'deb-src http://depo.pardus.org.tr/pardus yirmibes main contrib non-free' | sudo tee /etc/apt/sources.list.d/src.list
echo 'deb-src http://depo.pardus.org.tr/pardus yirmibes-deb main contrib non-free' | sudo tee -a /etc/apt/sources.list.d/src.list
sudo apt update && apt source xfce4-panel
```

### 16.3 Ne değiştirmek istiyorum → nereye dokunurum → neyi yeniden çalıştırırım

Satır yerine bölüm başlıklarını veriyorum, satır numaraları değişebilir. Betiklerdeki
`# ---------- …` başlıklarıyla bulunur.

| Değişiklik | Dokunulacak yer | Sonra çalıştır |
|---|---|---|
| **Kernel ayarı** (sürücü ekle/çıkar) | `linux/arch/arm64/configs/t3_gem_o1_defconfig` ya da `02-kernel.sh` içindeki `scripts/config … -e/-d` satırı | `02-kernel.sh`, `03` (yeni `.deb` rootfs'e otomatik kurulur, bkz. "2b"), `04` |
| **Donanım tanımı** (pin, I2C/SPI aygıtı, PMIC, LED) | `linux/arch/arm64/boot/dts/ti/k3-am67a-t3-gem-o1.dts` ve `k3-am67a-t3-gem-o1-pinmux.dtsi` | `02`, `03`, `04` |
| **Kart tanımı** (Debian ve mainline çekirdeği; pin, aygıt, Ethernet, HDMI) | `board/dts/`: görüntü dışı her şey `-common.dtsi`, HDMI/ses `-display.dtsi` (`board/dts/README.md`) | `DTB_ONLY=1 kernels/<ad>/build.sh` (saniyeler), sonra `05` ya da `./build.sh …` |
| **Debian çekirdeği: ayar** | `kernels/debian/build.sh` içindeki `$S -e/-m/-d` satırları | `./build.sh desktop --rebuild-kernel` ya da `kernels/debian/build.sh`, sonra `05` |
| **Mainline çekirdek: ayar / sürüm** | Ayar: `kernels/mainline/build.sh` "2) config". Sürüm: `versions.env` → `MAINLINE_VERSION`, `MAINLINE_SHA256` (kernel.org `sha256sums.asc`) | `./build.sh headless --rebuild-kernel`, sonra `05` |
| **Herhangi bir sabit sürüm** (derleyici, U-Boot, TF-A, OP-TEE, firmware, Debian çekirdeği) | `versions.env` | `00` (kaynaklar), ilgili derleme adımı |
| **Sistem boyutu / çekirdek seçimi** | `./build.sh image --flavor … --kernel …` ya da `03`'ün `--flavor` / `--kernel` seçenekleri (§25.3) | `03`, `04` |
| **Overlay etkinleştirme** (kamera, DSI ekran, PWM, SPI, UART) | `-vboot`: `03` içindeki `uEnv.txt` yazımında `overlays=` satırı ve `boot_mmc`'ye `run get_overlays;` eklemek. Kartta hızlıca: BOOT bölümündeki `uEnv.txt` | Kartta değiştirdiyseniz hiçbir şey. Kalıcı olsun istiyorsanız `03`, `04` |
| **Yeni overlay yazma** | `linux/arch/arm64/boot/dts/ti/<ad>.dtso` + aynı dizindeki `Makefile` içine `dtb-$(CONFIG_ARCH_K3) += <ad>.dtbo` | `02`, `03`, `04` |
| **Kernel komut satırı** (konsol, root, ek parametre) | `03`'te `-vboot` `uEnv.txt`: `optargs=` ve `args_mmc=` | `03`, `04` (ya da karttaki `uEnv.txt`) |
| **Paket ekleme** (tek seferlik) | `sudo EXTRA_PKGS="paket1 paket2" DISTRO=pardus ./scripts/03-rootfs-image.sh` | Aynı komut, sonra `04` |
| **Paket ekleme** (kalıcı, sıfırdan kurulumda da gelsin) | `03`, `setup.sh` içinde `inst` listeleri (sistem: `APT_OPTS=--no-install-recommends inst \`; masaüstü: `pardus` dalındaki `APT_OPTS= inst pardus-xfce-desktop …`) | Yeni kurulumda kendiliğinden gelir. Mevcut rootfs için `EXTRA_PKGS` |
| **Paket engelleme / sabitleme** | `03`, "2. configure + packages": `preferences.d/no-grub-plymouth`, `preferences.d/arm64-xfdesktop` | Sıfırdan kurulum (§16.4) ya da kartta `/etc/apt/preferences.d/` |
| **Depo / ayna** | `03` başı: `PARDUS=` / `MIRROR=`; `sources.list` yazımı ("2. configure + packages") | Sıfırdan kurulum (§16.4) |
| **Kullanıcı adı / ilk şifre** | `03`: `USERNAME=${USERNAME:-pardus}` ve `setup.sh` içindeki `chpasswd` satırı (`temppwd`) | Sıfırdan kurulum ya da kartta `passwd` |
| **Hostname** | `03`: `echo gemstone > "$ROOTFS/etc/hostname"` ve `/etc/hosts` | Sıfırdan kurulum ya da kartta `hostnamectl set-hostname` |
| **Dil / klavye** | `03` başı: `SYSLANG=`, `XKB=` | Sıfırdan kurulum ya da kartta `localectl` |
| **Sabit IP** | `03` başı: `NET_IP`, `NET_PREFIX`, `NET_GW`, `NET_DNS`, `NET_PC` (ya da ortam değişkeni: `sudo NET_IP=192.168.1.50 …`) | `03`, `04` (rootfs yeniden kurulmaz, yalnızca imaj) |
| **Ethernet işaret servisini kapatma** | `03`, "network": `gemstone-beacon.service` bloğu; kartta `sudo systemctl disable --now gemstone-beacon` | `03`, `04` |
| **İmaj boyutu** | `03` başı: `IMG_SIZE` (T3 initramfs ilk açılışta zaten kartın tamamına büyütür) | `03`, `04` |
| **Bölüm düzeni / FAT biçimi** | `03`, "4. disk image": `parted …` ve `mkfs.vfat -F 32 -s 1 -h 0 -g 16/32`. **Değiştirmeyin:** ROM yalnızca bu biçimde açtı (§12 #20) | — |
| **İlk açılışta büyütmeyi kapatma** | `03` `-vboot` `uEnv.txt`: `firstboot=0` | `03`, `04` |
| **Bootloader / initramfs seçimi** | Varsayılan zaten bizimki (`-own`). T3'ün dosyalarıyla karşılaştırma: `sudo ./go-pardus --vendor-bl` ve/veya `--vendor-initrd` (`vendor-boot/` gerekir; §18.5) | `01` (gerekirse), `03`, `04` |
| **U-Boot varsayılan açılış komutları** | `u-boot/board/t3/t3-gem-o1/t3-gem-o1.env` | `01`, `03` (`VENDOR_BOOT=` ile), `04` |
| **DDR / PMIC / güç yapılandırması** (yalnız yeni kart revizyonu için) | `u-boot/arch/arm/dts/k3-am67a-t3-gem-o1-ddr-lp4.dtsi`, `u-boot/board/t3/t3-gem-o1/*.yaml` | `01`, `03`, `04` |
| **TF-A / OP-TEE sürümü** | `versions.env` → `TFA`, `OPTEE` (adres, etiket, commit); derleme bayrakları `01` [1/4], [2/4] | `00`, `01`, `03`, `04` |
| **HS-SE (güvenli) silikon** | `01` sonu: `tiboot3-j722s-hs-evm.bin` dosyasını `tiboot3.bin` olarak kopyalamak | `01`, `03`, `04` |

`03` ve `04` root ister. Kısa yol: `./build.sh desktop` (03'ü sudo ile kendisi çağırır), ardından
`sudo ./scripts/04-flash-sd.sh /dev/sdb lite`.

### 16.4 Yeniden çalıştırma mantığı (betik neyi atlar)

| İşaret dosyası (`build/rootfs-pardus-yirmibes/`) | Anlamı | Silerseniz |
|---|---|---|
| `.stage1-done` | debootstrap bitti | **Sıfırdan kurulum:** betik rootfs dizinini silip debootstrap'tan başlar (~1 saat, internet gerekir) |
| `.stage2-done` | Paketler, kullanıcı, kernel kuruldu | Tek başına silmek işe yaramaz: betik bitmiş bir kurulumu tanıyıp işareti geri koyar. Paket ayarlarını yeniden uygulamak için sıfırdan kurulum gerekir |
| `.kernel-deb` | Rootfs'teki kernel `.deb`'inin sha256'sı | `.deb` değişince ya da dosya silinince kernel yeniden kurulur (~2 dk) |
| `.gpu-1` | GPU/C7x firmware'i ve (masaüstlüde) Mesa 26 kuruldu ("2c") | Bu adım yeniden çalışır |
| `.slim-1` | `lite`/`minimal`: geliştirme araçları, belgeler, fazla diller silindi | Bu adım yeniden çalışır |

Bu dosyalar yalnızca derleme klasöründedir; imaja kopyalanmaz.

Sıfırdan kurulum:

```bash
sudo rm ~/gemstone/build/rootfs-pardus-yirmibes/.stage1-done && sudo ./go-pardus
```

Ağ ayarı, işaret servisi, boot dosyaları ve imaj **her çalıştırmada** baştan üretilir
(~15 dk: rootfs kopyası + xz). Bu yüzden IP, `uEnv.txt` ya da bölüm değişiklikleri hızlıdır.

---

## 17. Kart özellikleri (T3 Gemstone O1)

✓ = bu projede kendi derlememizde, DTS'te ya da kartta gördük. İşaretsiz satırlar kart
belgelerinden alındı (kaynaklar bölüm sonunda) ve henüz doğrulanmadı.

### 17.1 İşlemci (TI AM67A / J722S)

| Birim | Özellik | Bizim imajda durum |
|---|---|---|
| Ana işlemci | 4 × ARM Cortex-A53, 64-bit, 1,4 GHz | Linux burada çalışıyor ✓ |
| Gerçek zamanlı çekirdekler | 2 × ARM Cortex-R5F, 800 MHz | Kullanılmıyor (NuttX/Zephyr için) |
| Önyükleme ve güvenlik çekirdeği | R5 + TIFS | Açılışta `tiboot3.bin` burada çalışıyor ✓ |
| Yapay zekâ hızlandırıcı | 2 × C7x DSP + MMA, her biri 2 TOPS, toplam 4 TOPS (8-bit, üreticinin tepe değeri) | Firmware ve TI kitaplıkları yok |
| GPU | Imagination PowerVR BXS-4-64, ~50 GFLOPS (DTS'te `gpu@fd80000`) ✓ | `DRM_POWERVR` kapalı, masaüstü yazılımla çiziliyor |
| Görüntü işleme | Kamera ISP'si (VPAC), donanım video kodlayıcı/çözücü | Denenmedi |

### 17.2 Bellek ve depolama

| Birim | Özellik | Bizim imajda durum |
|---|---|---|
| RAM | 4 GB LPDDR4 | |
| eMMC | 32 GB, kart üzerinde | Kullanılmıyor (§14) |
| EEPROM | 512 Kbit, kart kimlik bilgileri | |
| microSD | Var | İmaj buradan açılıyor ✓ |
| M.2 2280 | PCIe x1 (Gen3) SSD yuvası. Kararsız SSD'ler için `k3-am67a-t3-gem-o1-pcie-link-speed-2.dtbo` overlay'i Gen2'ye düşürür ✓ | `lspci` ile test edilecek (§13.3) |

### 17.3 Ağ ve kablosuz

| Birim | Özellik | Bizim imajda durum |
|---|---|---|
| Ethernet | 1 × Gigabit | Çalışıyor: açılış ARP sinyalleri görüldü ✓ |
| Wi-Fi | Realtek RTL8822CS, SDIO (`sdhci2`) ✓. Belgeler "Wi-Fi 4 (802.11n)" diyor, ama yonga 802.11ac (Wi-Fi 5), 2,4 ve 5 GHz destekler | Sürücü `rtw88_8822cs` ve firmware imajda, test edilecek |
| Bluetooth | 5.1 / BLE, aynı yongada, UART üzerinden ✓ | Test edilecek |
| CAN | 1 × CAN bus | Test edilecek |

### 17.4 Görüntü ve kamera

| Birim | Özellik | Bizim imajda durum |
|---|---|---|
| HDMI | 1 × HDMI | Giriş ekranı geliyor ✓ |
| MIPI CSI/DSI | 2 × 4-hatlı konnektör: kamera ya da DSI ekran | Overlay ile seçilir (`uEnv.txt` → `overlays=`), denenmedi |

### 17.5 Kart üstü sensörler

| Sensör | Ne ölçer | Not |
|---|---|---|
| InvenSense ICM-20948 | İvmeölçer, jiroskop, pusula (IMU) | DTS'te var ✓ |
| Barometre | Hava basıncı | Belgeler hem Bosch BMP390 hem ST LPS22DF diyor. Bizim DTS'te **LPS22DF** var ✓ (kart revizyonuna göre değişebilir) |
| TI HDC2010 | Nem ve sıcaklık | |

### 17.6 Genişleme ve G/Ç

| Birim | Özellik |
|---|---|
| 40-pin HAT başlığı | GPIO, UART (MAIN1), I2C, SPI |
| PWM | 7 × servo çıkışı |
| S.Bus | RC alıcı girişi (drone ve robot) |
| Fan | PWM hız kontrollü fan konnektörü |
| USB | 4 × USB |

### 17.7 Güç ve diğer

| Birim | Özellik |
|---|---|
| USB-C güç | 5–9 V / 3 A |
| DC jak | 5–12 V (belgeler 3 A ile 5 A arasında çelişiyor) |
| PMIC | TI güç yönetim entegresi, I2C adresi 0x30 ✓ (T3'ün Ağustos imajında 0x40, upstream düzeltme `9f1671a73`) |
| RTC | Gerçek zamanlı saat |
| LED | Yeşil ve kırmızı durum LED'leri |

**Belgelerde bulunamayanlar (kartın üstünden ya da T3 donanım kılavuzundan doğrulanmalı):**
kart ölçüleri, reset/boot düğmeleri, USB portlarının kaçının USB 3 olduğu, HDMI'nin en yüksek
çözünürlüğü, M.2 yuvasının kartın hangi yüzünde olduğu.

**Kaynaklar:**
[Apache NuttX – T3 Gemstone O1](https://nuttx.apache.org/docs/latest/platforms/arm/am67/boards/t3-gem-o1/index.html) ·
[ArduPilot – T3 Gemstone O1 Overview](https://ardupilot.org/sub/docs/common-t3-gem-o1-overview.html) ·
[Zephyr – T3 Gemstone O1](https://docs.zephyrproject.org/latest/boards/t3gemstone/t3_gem_o1/doc/index.html) ·
[TI AM67A ürün sayfası](https://www.ti.com/product/am67a) ·
DTS: `linux/arch/arm64/boot/dts/ti/k3-am67a-t3-gem-o1.dts`

---

## 18. Sıfırdan rehber: kart nasıl açılır, her parça nerede ve nasıl derlenir

Bu bölüm, gömülü Linux ile hiç uğraşmamış biri için yazıldı. Önceki bölümlerdeki bilgileri
tekrar etmek yerine sırayla anlatır ve ayrıntı için ilgili bölüme yönlendirir.

### 18.1 Önce birkaç kavram

| Terim | Basitçe |
|---|---|
| **Kart (board)** | T3 Gemstone O1. Üzerinde TI AM67A işlemcisi (SoC) var. Bilgisayar gibi ama küçük ve ARM tabanlı. |
| **SoC** | "System on Chip": işlemci çekirdekleri, bellek denetleyicisi, GPU, USB, Ethernet vb. tek bir yongada. AM67A'nın içinde **farklı türde birkaç işlemci** var (A53, R5F, C7x). |
| **Build makinesi** | Yazılımı derlediğimiz bilgisayar (Pardus 25 / Debian 13 tabanlı). Kart kendi yazılımını derlemez; her şey bu makinede hazırlanıp karta taşınır. |
| **Çapraz derleme** | x86 (Intel/AMD) bir makinede, ARM işlemcide çalışacak program üretmek. Bunun için özel derleyici gerekir: `aarch64-linux-gcc` (64-bit ARM) ve `arm-linux-gnueabi-gcc` (32-bit ARM). |
| **İmaj (.img)** | SD kartın bayt bayt kopyası. Karta "yazmak", bu dosyayı kartın başından itibaren olduğu gibi kopyalamaktır. |
| **Bölüm (partition)** | SD kart iki parçaya ayrılmış: **p1 `BOOT`** (FAT32, 128 MB, her sistemde görünür) ve **p2 `rootfs`** (btrfs, Pardus'un kendisi). |
| **Bootloader** | Güç verildikten sonra, Linux'tan önce çalışan küçük programlar. Belleği ve donanımı hazırlar, Linux'u yükler. |
| **Kernel (çekirdek)** | Linux'un kendisi: `Image` dosyası. Donanımla konuşan katman. |
| **DTB (device tree)** | Kernel'e "bu kartta hangi donanım, hangi adreste" bilgisini veren tarif dosyası: `k3-am67a-t3-gem-o1.dtb`. |
| **Overlay (.dtbo)** | DTB'ye sonradan eklenen yama: kamera, ekran gibi isteğe bağlı donanımları açar. |
| **initramfs (initrd)** | Kernel'in açılışta belleğe aldığı küçük geçici dosya sistemi. Asıl sistemi (p2) bulup bağlar, sonra kontrolü ona verir. |
| **rootfs** | Asıl işletim sistemi: Pardus'un tüm programları, masaüstü, ayarlar. p2'de durur. |
| **Firmware** | Donanımın içinde çalışan, genelde üreticinin kapalı kodlu küçük programları (ör. TI'ın güvenlik firmware'i, Wi-Fi yongasının firmware'i). |

### 18.2 Kart açılırken ne oluyor (her aşama tek tek)

Güç verildiği andan masaüstüne kadar **9 aşama** var. Her biri bir sonrakini yükleyip çalıştırır.
Bir aşama bozulursa zincir orada durur. Bu yüzden her aşamada "bozulursa ne görürsünüz" de yazılı.

```
 Güç ──► ① ROM ──► ② tiboot3.bin ──► ③ tispl.bin ──► ④ u-boot.img ──► ⑤ uEnv.txt
                     (R5F çekirdeği)     (A53 çekirdekleri)
                                          ├ TF-A
                                          ├ OP-TEE
                                          └ DM firmware (R5F'e geri döner)
     ──► ⑥ Kernel + DTB ──► ⑦ initramfs ──► ⑧ systemd (Pardus) ──► ⑨ giriş ekranı / XFCE
```

| # | Aşama | Nerede çalışır | Ne yapar | Dosya ve kartta yeri | Kim yazdı / nerede derlenir | Bozulursa ne görürsünüz |
|---|---|---|---|---|---|---|
| ① | **ROM kodu** | SoC'nin içinde, fabrikada yakılmış | Boot switch'lerine bakar, SD karttaki FAT bölümünden `tiboot3.bin`'i okur | — (yonganın içinde) | TI. Değiştirilemez. | Hiçbir şey: LED, ARP, HDMI yok. En sık neden FAT biçimi (§12 #20) |
| ② | **tiboot3.bin** | R5F (32-bit ARM, gerçek zamanlı çekirdek) | **DDR belleği başlatır** (karta özel ayar!), saatleri ve güç yönetimini kurar. İçinde TI'ın güvenlik firmware'i **TIFS** ve kart ayarları (`*.yaml`) da vardır | `BOOT/tiboot3.bin` | U-Boot (R5 SPL) + TIFS. **derleme makinesinde `01-bootloader.sh`** derler (§7) | Hiçbir şey olmaz; ① ile aynı belirti |
| ③ | **tispl.bin** | A53 (64-bit ARM, ana çekirdekler) | Dört parçalı bir paket: **TF-A** (güvenlik izleyicisi), **OP-TEE** (güvenli işletim sistemi, §18.3), **A53 SPL** (sıradakini yükler), **DM firmware** (R5F'e geri dönüp güç ve saat isteklerini karşılar) | `BOOT/tispl.bin` | TF-A + OP-TEE + U-Boot + TI DM. **derleme makinesinde `01-bootloader.sh`** | Hiçbir şey ya da ARP yok |
| ④ | **u-boot.img** | A53 | Tam U-Boot: SD kartı, FAT'ı, Ethernet'i tanır. Ortam değişkenlerine (env) göre ne yükleyeceğine karar verir | `BOOT/u-boot.img` | U-Boot (`t3gemstone/u-boot`). **derleme makinesinde `01-bootloader.sh`** | ARP yok (`uEnv.txt` okunmadı) |
| ⑤ | **uEnv.txt** | U-Boot'un içinde | Bizim ayarlarımız: kernel komut satırı, IP adresi, açılış işaretleri. `args_mmc` ve `boot_mmc` ile U-Boot'un varsayılanlarını değiştirir | `BOOT/uEnv.txt` (düz metin, herhangi bir metin düzenleyiciyle açılır) | **`03-rootfs-image.sh`** yazar (§10.1) | Wireshark'ta `Who has 10.42.0.11?` görünür ama devam etmez; ya da `Who has 10.42.0.99?` (kernel başlatılamadı) |
| ⑥ | **Kernel + DTB** | A53 | Linux başlar, donanımı DTB'ye göre tanır. HDMI'da Linux logosu (penguen) ve mesajlar çıkar | `BOOT/Image`, `BOOT/k3-am67a-t3-gem-o1.dtb`, `BOOT/overlays/*.dtbo` | Linux (`t3gemstone/linux`). **derleme makinesinde `02-kernel.sh`** (§8) | `10.42.0.99` ARP'si, ya da logo var ama mesajlar bir yerde durur |
| ⑦ | **initramfs** | A53, bellekte | Asıl sistemi (p2, btrfs) bulup bağlar ve ona geçer (`switch_root`) | `BOOT/gemstone-image-rd-t3-gem-o1.cpio.gz` (adı T3'ten kalma; U-Boot bu adı arıyor) | `-own`: Debian **initramfs-tools**, `03` içinde chroot'ta `update-initramfs` üretir. `-vboot`/`-ownbl`: T3'ün hazır dosyası (§18.5) | HDMI'da `root ... doesn't exist` ya da `(initramfs)` istemi |
| ⑧ | **systemd / Pardus** | A53 | Servisler başlar: ağ (sabit IP), SSH, işaret pingi, **ilk açılışta bölüm büyütme** | p2 `rootfs` | Pardus/Debian paketleri; **`03-rootfs-image.sh`** kurar (§9, §15) | 5 saniyelik ping yok, SSH açılmaz |
| ⑨ | **Giriş ekranı** | A53 | LightDM → XFCE masaüstü | p2 | Pardus paketleri | HDMI'da yalnızca konsol yazıları |

**Neden bu kadar çok aşama?** Açılışın en başında bellek (DDR) henüz çalışmıyor; yalnızca SoC'nin
içindeki küçük bir SRAM var. Her aşama bir sonraki, daha büyük aşamanın çalışabileceği ortamı
hazırlar: ROM yalnızca küçük bir dosyayı okuyabilir, tiboot3 belleği açar, tispl güvenlik ve güç
katmanlarını kurar, U-Boot da artık her şeyi okuyabildiği için büyük kernel'i yükler.

### 18.3 OP-TEE nedir?

ARM işlemcilerde **TrustZone** adlı bir donanım özelliği var: işlemci aynı anda iki "dünya"
çalıştırabilir.

- **Normal dünya:** Linux ve tüm programlarımız.
- **Güvenli dünya:** Linux'un **göremediği ve dokunamadığı** ayrı bir bellek ve çalışma alanı.

**OP-TEE** (Open Portable Trusted Execution Environment), güvenli dünyada çalışan küçük, açık
kaynaklı bir işletim sistemidir. Telefonlardaki "parmak izini ve kart bilgilerini saklayan güvenli
bölge" fikrinin aynısı.

**Ne işe yarar:**

- **Anahtar saklama:** Şifreleme anahtarları güvenli dünyada durur. Linux ele geçirilse bile
  anahtarlar okunamaz.
- **Güvenli depolama:** Şifrelenmiş, yalnızca OP-TEE'nin açabildiği veri.
- **Güvenilir uygulamalar (TA):** Güvenli dünyada çalışan küçük programlar; ör. lisans kontrolü,
  ödeme, kimlik doğrulama. Linux'taki bir program bunlarla `/dev/tee0` üzerinden konuşur.
- **Yazılım TPM'i (fTPM):** PC'lerdeki TPM yongasının yazılımla taklidi: disk şifreleme, ölçülü
  açılış.

**Zincirdeki yeri:** OP-TEE, `tispl.bin`'in içinde gelir. **TF-A** (Trusted Firmware-A) iki
dünya arasındaki kapı bekçisidir: işlemcinin en yetkili seviyesinde (EL3) çalışır ve geçişleri
yönetir. `01-bootloader.sh` TF-A'yı `SPD=opteed` ile derler; bu, "güvenli tarafta OP-TEE var" demektir.

**Bizim projede:**

| | |
|---|---|
| Kaynak | `github.com/OP-TEE/optee_os`, sürüm `4.6.0` → `~/gemstone/optee_os/` |
| Derleme | `01-bootloader.sh` adım 2: `make PLATFORM=k3-am62x CFG_ARM64_core=y CFG_WITH_SOFTWARE_PRNG=y` |
| Çıktı | `~/gemstone/build-user/optee/core/tee-pager_v2.bin` (TF-A'nın beklediği biçim) |
| Karta gidişi | U-Boot A53 derlemesine `TEE=…` ile verilir, binman onu `tispl.bin`'in içine paketler |
| Şu anki kullanım | Açılış zincirinin zorunlu parçası olarak çalışıyor; Linux tarafında henüz bir TA kullanmıyoruz |
| Kartta kontrol | `ls /dev/tee*` (Linux'ta OP-TEE sürücüsü açıksa görünür), `dmesg \| grep -i optee` |
| İleride | Güvenli açılış (yalnızca imzalı yazılım), şifreli depolama, fTPM ile disk şifreleme |

### 18.4 Derleme nerede yapılır

Tüm derleme bir **Pardus 25 (x86_64) derleme makinesinde** (Debian 13 tabanlı her dağıtım olur)
yapılır.

1. **Çalışma klasörü:** her şey `~/gemstone/` altında (dizin haritası §4.1).
   ```bash
   cd ~/gemstone
   ```

Kural: `01` ve `02` normal kullanıcıyla çalışır; `03` ve `04` **`sudo`** ister (disk imajı ve
SD kart işlemleri yönetici yetkisi gerektirir).

### 18.5 Her parça nasıl derlenir (sırayla)

Hepsini ilk kez yapıyorsanız sıra **A → B → C → D → E**. Sonraki seferlerde yalnızca
değiştirdiğiniz parçanın adımını ve ondan sonrakileri çalıştırırsınız (§16.3).

**A. Hazırlık (bir kez):** Derleme makinesi paketleri §6.2, çapraz derleyiciler ve kaynak kodlar §6.3.
Yaklaşık 20 dakika ve birkaç GB indirme.

**B. Bootloader: tiboot3 + tispl + u-boot (aşama ② ③ ④)**

```bash
cd ~/gemstone
./scripts/01-bootloader.sh 2>&1 | tee out-bootloader.log
```

| | |
|---|---|
| Süre | ~3 dakika |
| İçeride ne olur | Sırayla TF-A → OP-TEE → U-Boot R5 (→ `tiboot3.bin`) → U-Boot A53 (→ `tispl.bin`, `u-boot.img`). TI firmware ikilileri `ti-linux-firmware/` klasöründen alınıp paketlere eklenir. |
| Çıktı | `out/boot/tiboot3.bin`, `out/boot/tispl.bin`, `out/boot/u-boot.img` |
| Başarılı mı? | Son satır `BOOTLOADER_OK` |
| Değiştirmek için | U-Boot ayarları: `u-boot/configs/am67a_t3_gem_o1_*_defconfig`, ortam değişkenleri: `u-boot/board/t3/t3-gem-o1/t3-gem-o1.env`, DDR: `u-boot/arch/arm/dts/k3-am67a-t3-gem-o1-ddr-lp4.dtsi` (dikkat, kartı açılmaz yapabilir) |

**C. Kernel + DTB + overlay'ler (aşama ⑥)**

```bash
cd ~/gemstone
JOBS=4 ./scripts/02-kernel.sh 2>&1 | tee out-kernel.log
```

| | |
|---|---|
| Süre | 45–60 dakika (en uzun adım) |
| İçeride ne olur | T3'ün kart yapılandırması (`t3_gem_o1_defconfig`) + bizim eklediğimiz birkaç seçenek → kernel, ~2800 modül, DTB ve overlay'ler → Debian paketi (`.deb`) |
| Çıktı | `out/boot/Image`, `out/boot/k3-am67a-t3-gem-o1.dtb`, `out/boot/overlays/*.dtbo`, `out/kernel/linux-image-*.deb` |
| Değiştirmek için | Sürücü açıp kapatmak: `02-kernel.sh` içindeki `scripts/config` satırları. Donanım tarifi: `linux/arch/arm64/boot/dts/ti/k3-am67a-t3-gem-o1.dts` |

**D. Pardus sistemi + initramfs + SD imajı (aşama ⑤ ⑦ ⑧ ⑨)**

```bash
cd ~/gemstone
sudo ./go-pardus --flavor lite --kernel debian     # günlük: out-pardus.log
# ya da hepsi birden (A–D): ./build.sh desktop      (§26)
```

| | |
|---|---|
| Süre | İlk kez ~60–75 dakika (paketler internetten iner); sonraki seferlerde ~10–20 dakika |
| İçeride ne olur | 1) `debootstrap` ile boş bir arm64 Pardus/Debian kurulur. 2) `qemu` sayesinde bu arm64 sisteme x86 derleme makinesinden "girilip" (`chroot`) paketler kurulur: masaüstü, Türkçe, araçlar, **bizim kernel `.deb`'i**. 3) Kernel kurulurken **initramfs-tools** otomatik olarak `initrd.img` üretir (§18.6). 4) Ağ ayarı, işaret servisi, bölüm büyütme servisi eklenir. 5) BOOT dosyaları `build/bootfs/` içinde toplanır, `uEnv.txt` yazılır. 6) 12 GB'lık boş bir imaj dosyası bölümlenir, p1 FAT32 (T3 düzeni), p2 btrfs; içi doldurulur. 7) `.xz` ile sıkıştırılır, `sha256` alınır. |
| Çıktı | `out/t3-gem-o1-pardus-yirmibes-arm64-<boyut>-AAAAGGAA-<tür>[-k<çekirdek>].img` (+ `.xz`, `.sha256`) |
| Başarılı mı? | Günlükte `IMAGE_OK` |

İmaj türü (`<tür>`) hangi parçaların bizim olduğunu söyler. `03`'ün komut satırı seçeneğiyle
seçilir (eski işaret dosyaları da okunur):

| Tür | Bootloader | initramfs | Seçmek için | Kartta |
|---|---|---|---|---|
| `-own` | **bizim** | **bizim** | (varsayılan) | ✅ açıldı (2026-11-15), **önerilen** |
| `-vbl` | T3'ün | **bizim** | `--vendor-bl` | — |
| `-vinitrd` | **bizim** | T3'ün | `--vendor-initrd` | — |
| `-vboot` | T3'ün | T3'ün | `--vendor-bl --vendor-initrd` | ✅ açıldı (2026-11-08) |

`-vbl`, `-vinitrd`, `-vboot` yalnızca karşılaştırma içindir ve `vendor-boot/` klasöründe T3'ün
dosyalarını ister (PROSEDUR §2.1). Kernel, DTB ve Pardus her türde bizimdir. Çekirdek seçimi
ayrıca `--kernel` ile yapılır (`lts-hdmi` → `-klts-hdmi`, §27; `debian` → `-kdebian`, §21; `mainline` →
`-kmainline`, §24; `t3` → ek yok).

> Tarihçe: 15 Kasım'a kadar varsayılan T3'ün dosyalarıydı ve bizimkiler `.own-bl`/`.own-initrd`
> işaretleriyle seçiliyordu (imaj adları `-ownbl`, `-owninit`). Bu belgenin eski bölümlerinde ve
> §1 tablosunda geçen bu adlar o dönemin imajlarıdır; betik artık bu adları üretmez.

**Sistem boyutu (`FLAVOR`):** yukarıdakilerden bağımsız ikinci bir seçim.

| Boyut | İçerik | Seçmek için | rootfs klasörü | İmaj adı |
|---|---|---|---|---|
| `full` | Pardus XFCE masaüstü, LibreOffice, Firefox, Pardus araçları | `--flavor full` | `build/rootfs-pardus-yirmibes` | `…-arm64-full-…` |
| `lite` | **Sade Pardus XFCE**: aynı Pardus paneli, teması ve araçları; ofis/tarayıcı/yazıcı/`xfce4-goodies`/geliştirme araçları yok, pencere efektleri, açılış zamanlayıcıları ve açılış mesajları kapalı. **Hız ve yapay zekâ uygulamaları için** (§19) | (varsayılan) `--flavor lite` | `build/rootfs-pardus-yirmibes-lite` | `…-arm64-lite-…` |
| `minimal` | **Masaüstü yok**: Pardus tabanı, SSH, NetworkManager, Wi-Fi/BT, Python 3. SSH ya da seri konsolla kullanılır (§24.3) | `--flavor minimal` | `build/rootfs-pardus-yirmibes-minimal` | `…-arm64-minimal-…` |

Örnek, masaüstlü en sade sistem, Debian çekirdeğiyle: `./build.sh desktop`. Ekransız, yamasız
çekirdekle: `./build.sh headless`. Başka bir birleşim: `./build.sh image --flavor full --kernel t3`.

**E. SD karta yazma**

```bash
lsblk -o NAME,SIZE,TRAN,MODEL           # kart okuyucuyu bulun (ör. sdb, TRAN=usb)
sudo ./scripts/04-flash-sd.sh /dev/sdb   # en yeni imajı yazar, geri okuyup karşılaştırır
```

Önce kart okuyucuyu derleme makinesine takın (sanal makine kullanıyorsanız okuyucuyu VM'e yönlendirin). Yazma ve
doğrulama ~10–15 dakika sürer; sonunda `VERIFY_OK` ve `FLASH_OK` görülmelidir. **Dikkat:**
`/dev/sdb` yanlışsa başka bir diskin üzerine yazılır; `lsblk` çıktısında boyut ve `usb`
ibaresini mutlaka kontrol edin.

**F. Kartta açma:** HDMI ve Ethernet bağlı, PC'nin Ethernet IP'si `10.42.0.11/24`, Wireshark
açık. Güç verin; belirtilerin anlamı §13.2 ve §18.2 tablosunda. Giriş: `pardus` / `temppwd`
(ilk girişte yeni şifre istenir), ağdan `ssh pardus@10.42.0.12`.

### 18.6 initramfs: T3'ünki ile bizimki ve Ethernet üzerinden deneme

**T3'ün initramfs'i ne yapıyor?** (`vendor-boot/gemstone-image-rd-t3-gem-o1.cpio.gz`, Yocto ile
üretilmiş BusyBox; içindeki betikler `init.d/` altında)

| Betik | İşi | Bizde karşılığı |
|---|---|---|
| `88-usbgadget` | Açılış sırasında USB-C üzerinden geçici bir seri port açar (yalnızca initramfs hata ayıklaması için; `98-gemfinish` kapatır) | Yok. Gerekirse Debian initramfs'in `break=` parametresiyle HDMI'da kabuk alınır |
| `89-firstboot` | `firstboot=1` ise p2'yi kartın sonuna kadar büyütür, btrfs'i büyütür, `uEnv.txt`'de `firstboot=0` yapar | **`gemstone-growroot.service`** (Pardus açıldıktan sonra, bir kez) |
| `90-rootfs` | `root=/dev/mmcblk1p2`'yi bağlar | Debian initramfs-tools'un `local` betiği |
| `99-finish` | `switch_root` ile Pardus'a geçer | initramfs-tools `run-init` |

**Bizim initramfs'imiz:** Debian'ın standart aracı **initramfs-tools**. Kernel `.deb`'i rootfs'e
kurulurken `update-initramfs` otomatik çalışır ve `/boot/initrd.img-6.12.24-t3-gem-o1+` dosyasını
üretir (gzip, ~15 MB). SD kart, MMC ve btrfs sürücüleri kernel'in içine gömülü (`=y`) olduğu için
initramfs ek modüle ihtiyaç duymaz. `03`, `-own`/`-owninit` imajında bu dosyayı BOOT bölümüne
T3'ün dosya adıyla koyar, çünkü U-Boot'un ortam değişkeni (`get_initrd_mmc`) tam o adı yüklüyor.

**Bölüm büyütme servisi** (`/usr/local/sbin/gemstone-growroot`, tüm imaj türlerinde var):
ilk açılışta kökün bulunduğu bölümü (`/dev/mmcblk1p2`) diskin sonuna kadar uzatır (`sfdisk`),
kernel'e bildirir (`partx`) ve btrfs'i büyütür (`btrfs filesystem resize max /`). Bitince
`/var/lib/gemstone/growroot.done` dosyasını bırakır ve bir daha çalışmaz. T3 initramfs'i bölümü
zaten büyütmüşse hiçbir şey değiştirmez. Kontrol: `systemctl status gemstone-growroot`, `df -h /`.

#### Ethernet üzerinden hızlı deneme (kartı yeniden yazmadan)

Kartta çalışan bir Pardus varken initramfs'i değiştirmek için SD kartı çıkarmaya gerek yok:
initramfs BOOT bölümünde duran tek bir dosya. Karttaki Pardus'un `/boot` klasöründe bizim
initramfs zaten var; yapılacak iş onu BOOT bölümüne kopyalamak.

Bilgisayarda (PC Ethernet'i `10.42.0.11`, kart açık):

```bash
ssh pardus@10.42.0.12
```

Kartta (şifre sorulunca kendi şifrenizi girin):

```bash
cd /boot/firmware                                                    # BOOT bölümü burada bağlı
sudo cp gemstone-image-rd-t3-gem-o1.cpio.gz t3-initramfs.yedek.cpio.gz   # 1) T3'ün dosyasını yedekle
sudo cp /boot/initrd.img-$(uname -r) gemstone-image-rd-t3-gem-o1.cpio.gz # 2) bizimkini yerine koy
sha256sum gemstone-image-rd-t3-gem-o1.cpio.gz /boot/initrd.img-$(uname -r) # 3) iki satır aynı olmalı
sync && sudo reboot                                                  # 4) yeniden başlat
```

Açıldıktan sonra tekrar bağlanıp kontrol:

```bash
sha256sum /boot/firmware/gemstone-image-rd-t3-gem-o1.cpio.gz   # hâlâ bizimki mi
journalctl -b | grep -i -m3 initramfs                         # açılışta hangi initramfs çalıştı
cat /proc/cmdline                                             # kernel'e verilen parametreler
```

**Açılmazsa geri dönüş:** Kartı bir bilgisayara takın; `BOOT` sürücüsünde `t3-initramfs.yedek.cpio.gz`
dosyasının adını `gemstone-image-rd-t3-gem-o1.cpio.gz` yapın (eskisini silin). Kart yine T3
initramfs'iyle açılır. HDMI'da `(initramfs)` istemi görünürse orada `cat /proc/cmdline` ve
`ls /dev/mmcblk*` çıktısı sorunun yerini gösterir.

Bu hızlı deneme yalnızca initramfs'i dener; bölüm büyütme servisini denemek için `-own` imajı
boş bir karta yazılmalıdır (ilk açılışta p2 ~11,9 GB'tan kartın tamamına büyümeli).

### 18.7 Bir şey ters giderse nereye bakılır

| Nerede | Ne var |
|---|---|
| `~/gemstone/out-bootloader.log`, `out-kernel.log`, `out-pardus.log`, `out-flash.log` | Her adımın tam çıktısı. Hata genelde son 30 satırda. |
| Wireshark (PC Ethernet) | Kart hangi aşamaya kadar geldi (§13.2.1) |
| HDMI | Kernel ve initramfs mesajları (`console=tty1`) |
| Kartı bir bilgisayara takınca `BOOT` sürücüsü | `uEnv.txt` (ayarlar), hangi dosyalar var |
| Kartta: `journalctl -b`, `dmesg`, `systemctl --failed` | Pardus açıldıysa tüm açılış kaydı |
| §12 | Şimdiye kadar yaşanan 20 sorun ve çözümleri |

---

## 19. Hafif sürüm (`lite`): minimal Pardus XFCE

**Amaç:** Görünüş ve kullanım tam Pardus XFCE olsun, ama kart hızlı açılsın ve belleğin çoğu bizim
uygulamalarımıza (özellikle yapay zekâ) kalsın. (İlk denemede Openbox planlandı; Pardus görünümü
için XFCE'de kalmaya karar verildi.)

**Yöntem:** Pardus'un `pardus-xfce-desktop` meta paketi zorunlu bağımlılık olarak bile ağır şeyler
getiriyor (`xfce4-goodies`'in tüm eklentileri, yazıcı sistemi, `gnome-system-tools`), önerdikleri de
LibreOffice, GIMP, VLC, Evolution gibi uygulamalar. `lite` bu paketi kurmaz; Pardus XFCE'yi oluşturan
parçaları **tek tek ve önerilen paketler olmadan** kurar. Panel eklentileri, Pardus panel ayarının
(`/etc/xdg/pardus/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml`) kullandıklarının aynısıdır.

| | `full` | `lite` |
|---|---|---|
| Masaüstü | Pardus XFCE (`pardus-xfce-desktop` + önerilenler) | **Aynı Pardus XFCE**: `pardus-xfce-settings` (Pardus panel düzeni, menü, Thunar ayarları), xfwm4, xfdesktop, xfce4-panel, Thunar, xfce4-terminal |
| Panel | Pardus paneli | Aynı: whiskermenu, görev listesi, sistem tepsisi, ses, bildirim, güç, saat, oturum düğmesi |
| Görünüm | Pardus teması | Aynı: `pardus-xfce-gtk-theme`, `pardus-xfce-icon-theme`, Pardus 25 duvar kağıdı, Ubuntu yazı tipi |
| Giriş ekranı | Pardus greeter (Python) | LightDM GTK greeter + Pardus'un kendi ayarı (`30-pardus.conf`); C ile yazılmış, daha hızlı açılır |
| Pardus araçları | Hepsi | Yazılım Merkezi, Güncelleyici, Bilgisayarım, Hakkında, Paket Yükleyici, Hotspot, Gece Işığı, USB Biçimlendirici, Disk Kalıbı Yazıcı, Yazı Tipi Yöneticisi, XFCE İnce Ayarlar. Yalnızca açılınca çalışırlar |
| Olmayanlar | — | LibreOffice, Firefox, GIMP, VLC, Evolution, yazıcı (cups), `xfce4-goodies`, plymouth, ekran kilidi (light-locker), XFCE ipuçları penceresi |
| Pencere efektleri | xfwm4 compositor açık | **Kapalı** (masaüstü işlemciyle çiziliyor, efektler yavaşlatır; GPU yalnızca Vulkan uygulamalarına açık, §23.3) |
| Açılışta kapatılanlar | — | `apt-daily`, `apt-daily-upgrade`, `man-db`, `e2scrub_all` zamanlayıcıları, `NetworkManager-wait-online` |
| Açılış mesajları | HDMI'da kernel mesajları | `quiet loglevel=3` (ekrana yazmak açılışı yavaşlatır). Hata ayıklarken BOOT'taki `uEnv.txt` içinde `optargs` satırından bu iki kelimeyi silin |
| Geliştirme araçları | gcc, cmake, git, vim, pip, man sayfaları | **Yok** (18 Kasım'dan beri). Gerekirse kartta `sudo apt install build-essential cmake git` |
| Belgeler ve diller | Hepsi | `/usr/share/doc` (lisans dosyaları hariç), man/info sayfaları ve Türkçe/İngilizce dışındaki çeviriler silinir; dpkg sonraki kurulumlarda da bunları yazmaz (`/etc/dpkg/dpkg.cfg.d/01-gemstone-lite`) |
| Aynı kalanlar | Bizim bootloader/kernel/initramfs, Pardus depoları ve güncellemeleri, Wi-Fi/BT, SSH, sabit IP, ses (PipeWire), Python 3, GStreamer, GPU (Vulkan) ve C7x firmware'i (§23) |

Eksik bir uygulama gerekirse kartta `sudo apt install <paket>` ile ya da Pardus Yazılım Merkezi'nden
kurulur; ya da imaja kalıcı eklemek için aşağıdaki listeye yazılır.

**Nerede tanımlı:** `scripts/03-rootfs-image.sh` → `setup.sh` içindeki
`if [ "$FLAVOR" = lite ] && [ "$DISTRO" = pardus ]` bloğu: paket listesi, ipuçları penceresinin
ve compositor'ün kapatılması, maskelenen servisler. `quiet`: "boot partition content" bölümünde
`QUIET=` satırı. Paket listesi değişirse lite rootfs'in yeniden kurulması gerekir:
`sudo rm ~/gemstone/build/rootfs-pardus-yirmibes-lite/.stage1-done` (ya da var olan rootfs'e
`EXTRA_PKGS="…"` ile ekleyin).

**Derleme:** `./build.sh desktop` (deponun klasöründe; `lite` + Debian çekirdeği; yalnız imaj
adımı: `sudo ./go-pardus --flavor lite --kernel debian`). İlk kez ~45–60 dk, ayrı bir rootfs
kurulur; tam sürüm bozulmaz. Çıktı: `out/t3-gem-o1-pardus-yirmibes-arm64-lite-AAAAGGAA-own-klts-hdmi.img`.

**Üçüncü boyut, `minimal`:** masaüstü hiç yok; kart yalnızca ağdan (SSH) ve seri konsoldan
kullanılır. Ayrıntı ve ölçümler §24.3.

| | `full` | `lite` | `minimal` |
|---|---|---|---|
| Masaüstü | Pardus XFCE, tam | Pardus XFCE, sade | yok (`multi-user.target`) |
| Paket sayısı | 1.786 | 817 | **285** |
| rootfs | ölçülmedi | 1,7 GB | **507 MB** |
| İmaj (ham / `.xz`) | 12 GB / ölçülmedi | 8 GB / 423 MB | **4 GB / 181 MB** |
| Mesa 26 (Vulkan) | ✅ | ✅ | — (grafik yığını yok; GPU firmware'i var) |
| Seçmek için | `--flavor full` | (varsayılan) `--flavor lite` | `--flavor minimal` |

(full'ün değerleri 8 Kasım rootfs'inden; lite ve minimal'inki 22 Kasım yayın imajlarından, `xz -6`.)

**Kartta ölçüm:**

```bash
systemd-analyze                 # açılış süresi (kernel + userspace)
systemd-analyze blame | head    # en yavaş 10 servis
free -h                         # boşta bellek kullanımı
```

**Ölçüm sonucu (2026-11-15, `lite-20261115-own` imajı, ilk sürüm):**

| | Değer |
|---|---|
| Kernel açılışı | 8,5 s |
| Kullanıcı alanı (giriş ekranına kadar, `graphical.target`) | 15,4 s |
| **Toplam** | **24,0 s** (bootloader süresi hariç) |
| Boşta kullanılan bellek | **480 MB** / 3,7 GB (2,7 GB boş, 3,2 GB kullanılabilir) |

Bu ilk lite sürümde Pardus giriş ekranı ve duvar kağıtları (`desktop-base`,
`pardus-lightdm-greeter`) yoktu; sonradan `LITE_PKGS` listesine eklendiler. Karşılaştırma için
aynı ölçüm `full` imajda yapılmalı.

---

## 20. Neden Debian'ın hazır kernel'ini kullanamıyoruz? (Kernel kaynağı kararı)

### 20.1 Kısa cevap

Debian'ın (ve Pardus'un) hazır Linux çekirdeği bu kartta açılır, ama **HDMI'dan görüntü vermez**.
Nedeni, kartın işlemcisindeki (TI AM67A / J722S) **görüntü biriminin (DSS)** ana Linux'ta henüz
desteklenmemesi. Bu destek şu an yalnızca işlemcinin üreticisi **TI'ın kendi Linux çekirdeğinde**
var. Bu yüzden çekirdeği TI'ın kaynağından derlemek zorundayız.

> **Güncelleme (16–17 Kasım 2026):** Bu bölüm Debian'ın **hazır paketini** inceler ve oradaki tespit
> hâlâ geçerli. Sonradan üçüncü bir yol bulduk ve kartta çalıştırdık: **Debian'ın çekirdek
> kaynağını alıp**, posta listesinde bekleyen HDMI yamalarını üstüne ekleyerek kendimiz derlemek.
> Görüntü desteği TI'ın çekirdeğine bağlı kalmadan geldi. Ayrıntılar §21'de; seçeneklerin güncel
> karşılaştırması §20.4'te.

### 20.2 Amaç neydi?

Projeyi kart üreticisine (T3) bağımlı olmaktan çıkarmak ve mümkün olduğunca **genel** yapmak:
çekirdeği kendimiz derlemek yerine Debian'ın hazır çekirdeğini kullanmak. Bunun faydaları:

- Çekirdek güncellemeleri ve güvenlik yamaları `apt upgrade` ile otomatik gelir.
- 45 dakikalık çekirdek derlemesi ortadan kalkar.
- Bakımı Debian ekibi yapar.

### 20.3 Ne kontrol ettik?

**1. Debian'ın çekirdek paketi** (`linux-image-6.12.116+deb13-arm64`, Pardus 25 deposu):

| Kartın parçası | Debian çekirdeğinde |
|---|---|
| İşlemci ailesi (TI K3), saat ve güç alanları | ✅ var |
| SD kart, Ethernet, PCIe, USB, I2C, CAN | ✅ var |
| Wi-Fi / Bluetooth (Realtek RTL8822CS) | ✅ var |
| HDMI köprü yongası (SiI9022) | ✅ var |
| Görüntü sürücüsü (`tidss`) | ✅ var, **ama bu işlemcinin görüntü birimini tanımıyor** (aşağıda) |
| Güç yönetim yongası (TI TPS65219) | ⚠️ Sürücü Linux'ta var, Debian kapatmış |
| Nem/sıcaklık sensörü (TI HDC2010) | ⚠️ Sürücü Linux'ta var, Debian kapatmış |

**2. "Tanımıyor" ne demek?**

Linux açılırken kartın donanım tarifini (device tree) okur. Tarifte her parçanın bir kimlik etiketi
vardır; kartımızın görüntü biriminin etiketi `ti,am62p52-dss`. Çekirdek bu etiketi tanıyan bir
sürücü arar. Her sürücünün içinde tanıdığı etiketlerin listesi vardır; etiket listede yoksa parça
hiç çalıştırılmaz.

İki sürücünün listesini kendi dosyalarından (`modinfo`, `strings`) çıkardık:

| Etiket | Debian'ın `tidss` sürücüsü | TI kaynaklı `tidss` (bizim kullandığımız) |
|---|---|---|
| `ti,am625-dss`, `ti,am62a7-dss`, `ti,am65x-dss` | ✅ | ✅ |
| `ti,j721e-dss`, `ti,k2g-dss` | ✅ | ✅ |
| `ti,am62l-dss` | ❌ | ✅ |
| `ti,am62p51-dss` | ❌ | ✅ |
| **`ti,am62p52-dss`** (kartın HDMI'ı buna bağlı) | ❌ | ✅ |

Debian'ın sürücüsü aynı ailenin diğer TI işlemcileri için yazılmış; bizim işlemcinin görüntü birimi
(AM62P/J722S'deki DSS) ailenin daha yeni bir üyesi. Etiketi değiştirip "eski işlemci" gibi
göstermek güvenilir değil: kayıt adresleri, çıkış sayısı ve saat ayarları farklı.

**3. Debian'ın hangi sürümünde var?** Hiçbirinde. Debian ana Linux'u takip ediyor ve ana Linux'ta bu
destek henüz yok:

| Ana Linux (kernel.org) | AM62P/J722S görüntü desteği | Debian'da |
|---|---|---|
| 6.12 | ❌ | Debian 13 "trixie" (Pardus 25'in tabanı): 6.12.107 / 6.12.116 |
| 6.13 – 6.19 | ❌ | — |
| 7.0 – 7.3 (en yeni) | ❌ | trixie-backports 7.2.12, forky 7.2.15, sid 7.3.4 |
| linux-next (geliştirme dalı) | ❌ | — |

(Kontrol: `drivers/gpu/drm/tidss/tidss_drv.c` içindeki tanınan yongalar listesi ve
`arch/arm64/boot/dts/ti/k3-am62p-j722s-common-main.dtsi` içinde görüntü birimi tanımı;
kernel.org, 16 Kasım 2026.)

### 20.4 Karar

| Seçenek | HDMI / masaüstü | Güncelleme | Karar |
|---|---|---|---|
| Debian'ın hazır çekirdeği | ❌ Görüntü yok | ✅ `apt` ile otomatik | Uygun değil |
| Debian çekirdek kaynağı, kendi ayarlarımızla | ❌ Görüntü yok (kaynakta destek yok) | ❌ Kendimiz derleriz | Uygun değil |
| TI'ın çekirdek kaynağı + genel `defconfig` + kendi ek ayarlarımız | ✅ Çalışması beklenir | ❌ Kendimiz derleriz | İlk karar (16 Kas); henüz hazırlanmadı |
| **Debian çekirdek kaynağı + HDMI yamaları + kart tarifi** (§21) | ✅ **Kartta çalışıyor** | ❌ Kendimiz derleriz (Debian tabanı, Debian ayarı) | **Şu an kullanılan** (17 Kas) |

Debian kaynağının üstüne yama yolu, TI yolunun hedeflediği her şeyi sağlıyor ve daha da genel:
çekirdek Debian'ın kendi kaynağı ve kendi ayar dosyası; bizim eklediğimiz yalnızca 22 HDMI yaması,
kart tarifi ve kısa bir ek ayar listesi. Yamalar ana Linux'a girdiğinde yalnızca kart tarifi kalır.

İlk karardaki (TI kaynağı) yol için yazılanlar aşağıda duruyor; bu yol hâlâ yedek seçenek:

- **Kaynak:** TI'ın resmi çekirdeği. Görüntü desteği olan tek kaynak. İşlemcinin üreticisi olduğu
  için bu bağımlılık kaçınılmaz.
- **Ayar:** Kart üreticisinin ayar dosyası yerine Linux'un **genel arm64 ayarı (`defconfig`)**.
  Bu ayar kartın ihtiyaçlarının neredeyse tamamını zaten açıyor (güç yongası ve görüntü dahil).
  Eksik kalan üç sürücü (Wi-Fi, Bluetooth, nem sensörü) için küçük bir ek ayar dosyası depomuzda
  tutulur. Bonus: genel ayarda GPU sürücüsü (PowerVR) de açık.
- **Kart tarifi (device tree):** Kartın donanım tarifi depomuzda tutulur. Kart üreticisine özel
  olan tek parça budur; her ARM kartta böyledir.

Sonuç: Proje **kart üreticisinden (T3) bağımsız** olur, yalnızca işlemci üreticisine (TI) bağlı kalır.

### 20.5 Ne zaman Debian çekirdeğine geçebiliriz?

TI bu işlemcinin görüntü desteğini ana Linux'a gönderip kabul edildiğinde ve bu sürüm Debian'a
geldiğinde. Aynı işlemciyi kullanan BeagleY-AI kartı da aynı desteğe ihtiyaç duyduğu için gelmesi
beklenir, ama tarihi belli değil. Takip için kernel e-posta listesi:
https://lore.kernel.org/dri-devel/?q=am62p+dss

O gün yapılacaklar: kart tarifini ana Linux'un yapısına uyarlamak, Debian'dan güç yongası ve nem
sensörü sürücülerinin açılmasını istemek (ya da modül olarak eklemek). Sonrasında çekirdek
derlemesi tamamen kalkar ve güncellemeler `apt` ile gelir.

Kart tarifi ana Linux yapısına zaten uyarlandı (§21.4). Debian'ın arm64 ayarında kapalı olan TI
parçaları da listelendi (§21.3); bunların açılması için Debian'a hata kaydı açılabilir.

---

## 21. Debian çekirdeği: 7.2.12 + HDMI yamaları

### 21.1 Kısaca

| | |
|---|---|
| **Çekirdek sürümü** | `7.2.12-gemstone+` (`uname -r` çıktısı) |
| **Paket** | `linux-image-7.2.12-gemstone+_7.2.12-1gemstone1_arm64.deb` (paket sürümü `7.2.12-1gemstone1`) |
| **Taban** | Debian'ın resmi kaynağı `linux 7.2.12-1~bpo13+1` (trixie-backports), Debian'ın kendi yamaları dahil |
| **Ayar** | Debian'ın kendi arm64 ayar dosyası + kısa bir ek liste (§21.3) |
| **Üstüne eklenen** | 24 yama: 22 HDMI yaması + ana Linux 7.4'ten alınmış 2 GPU/VPU yaması (§21.2, §23). Kart tarifi yama değil, `board/dts/`'den derlenir (§21.4) |
| **Derleyici** | GCC 11.5.0 (çapraz), derleme makinesinde, ~60–90 dk |
| **Betik** | `kernels/debian/build.sh` (sürümler `versions.env`'de) |
| **Çıktı** | `kernels/debian/out/`: `.deb`, `Image`, `k3-am67a-t3-gem-o1.dtb`, `release` |
| **Kartta** | ✅ 17 Kasım 2026 02:46 derlemesi çalışıyor: HDMI ekran, HDMI ses, Ethernet 1 Gbps, Wi-Fi, BT, SD, eMMC, NVMe, USB, CAN. ✅ 18 Kasım derlemesiyle GPU (Vulkan) ve C7x DSP'ler de (§23) |

Kullanıcı gözüyle: kart artık **kart üreticisinin (T3) 6.12 çekirdeğiyle değil**, Debian'ın 7.2
çekirdeğiyle açılıyor. T3'e bağlı tek parça kartın donanım tarifi (DTS), o da artık depomuzda.

### 21.2 Neden yama gerekiyor?

Kartın HDMI'ı işlemcinin görüntü birimine (DSS) bağlı ve bu birimin sürücüsü ana Linux'ta henüz
yok (§20). TI'dan Tomi Valkeinen bu desteği posta listesine gönderdi; henüz kabul edilmedi. Biz bu
yamaları alıp Debian kaynağına uyguladık:

| Yamalar | Ne yapıyor | Kaynak |
|---|---|---|
| 0001–0006 | İşlemcinin "main conf" bölgesini ortak (syscon) tanımlar; HDMI yamalarının ön şartı | Tomi Valkeinen, *arm64: ti: Use syscon for the main conf* (6 yama, Mayıs 2026) |
| 0007–0022 | AM62P/J722S görüntü birimi desteği ve HDMI | Tomi Valkeinen, *drm/tidss: Add BeagleY-AI display support* v3 (15 yama, Mayıs 2026) |
| 0023 | GPU (PowerVR BXS-4-64) tanımı işlemci tarifine eklenir | Ana Linux, **v7.4'e girdi** (commit `9c8d40bf`); olduğu gibi alındı (§23) |
| 0024 | Video birimine (VPU) ek SRAM verilir | Ana Linux, v7.4'e girdi (commit `330236fd`, Brandon Brnich); olduğu gibi alındı |

22 Kasım'a kadar seride 27 yama vardı: kart tarifi 0023–0025 numaralı yamalardı, GPU/VPU yamaları
0026–0027 idi. Kart tarifi `board/dts/`'ye taşınınca bu ikisi 0023–0024 oldu. Kartta çalışan
çekirdek o 27 yamalı ağaçtan derlendi; çekirdeğin kendisi (`Image`, modüller) bu düzenlemeden
etkilenmedi, yalnızca DTB artık `board/dts/`'den geliyor (§21.4).

**Yamalar hangi dala gönderildi?** Hepsi ana Linux'un **geliştirme** sürümüne (mainline), uzun
destekli (LTS) sürümlere değil:

| Yamalar | Gönderildiği ağaç | Durum (21 Kasım 2026) |
|---|---|---|
| 0001–0022 (Tomi Valkeinen) | DRM için `drm-misc-next`, kart tarifleri için TI'ın `ti-k3-dts-next` | **Kabul edilmedi.** v3 29 Mayıs 2026. 3 Eylül 2026'da 10 yamalık küçük bir "hazırlık" serisi gönderildi ve "kuyruğa alındı" denildi; hangi ağaca alındığı yazılmadı. Asıl HDMI yamaları hâlâ bekliyor |
| 0023–0024 | `ti-k3-dts-next` | ✅ Kabul edildi, ana Linux **7.4**'te (7.4 henüz çıkmadı; şu an 7.4-rc3) |

v3 serisinin 11. yamasının bir parçası 7.2.12'ye olduğu gibi uymadı; elle uyarlandı (0017 + 0022).
Yamaların listesi ve bağlantıları: `kernels/debian/patches/README.md`.

### 21.3 Ayar (config): Debian'ın ayarında neyi değiştirdik?

Debian'ın ayar dosyası, Debian'ın kendi ikili paketinden (`linux-base-7.2.12+deb13-arm64`) alınır;
yani Debian'ın kullandığının birebir aynısıdır. Üstüne şunlar eklenir (`build.sh` içinde, her biri
gerekçesiyle):

| Değişiklik | Neden |
|---|---|
| TI K3 kesme yönlendiricileri, DMA (UDMA, ring accelerator, PSI-L) **açık** | Debian 7.2'nin arm64 ayarında kapalı. Bunlar olmadan GPIO kesmeleri çalışmıyor → SD kartın güç anahtarı açılmıyor → **kart açılmıyor**. İlk denemede yaşandı. |
| Ethernet anahtarı (CPSW), MDIO, PHY seçimi | Kapalıydı; Ethernet yoktu |
| McASP ses, DSI/DPHY, SerDes, USB2 PHY, RTC, kamera alıcısı, uzak işlemciler | Kartın donanımı; Debian'da kapalı |
| Güç yongası (TPS65219) ve güç düğmesi, nem sensörü (HDC2010) | Kartın donanımı; Debian'da kapalı |
| CAN alıcı-verici PHY, fan PWM (ehrpwm), JPEG kodlayıcı, VPU (video) | İlk açılışın dmesg'inde eksik çıktılar (§21.6) |
| GPU sürücüsü `DRM_POWERVR` (modül) | Debian'da kapalı; GPU için (§23) |
| SA2UL kripto hızlandırıcı **kapalı** | Bu çekirdekte kendi testlerinde hata verip çöküyordu (Oops). Şifreleme işlemcinin AES komutlarıyla yapılır. |
| `DRM_PANIC_SCREEN=kmsg` | Debian'ın QR kodu Rust ister; Rust'sız derliyoruz |
| Modül imzalama açık, anahtar derlemede üretilir | Debian'ın imza anahtarı bizde yok; imzasız modüller çekirdeği "kirli" (taint) işaretliyordu |
| Hata ayıklama bilgisi kapalı, sürüm eki `-gemstone` | Paket küçük kalsın; çekirdeğimiz Debian'ınkinden ayırt edilsin |

### 21.4 Kart tarifi (DTS)

Kart tarifi T3'ün 6.12 çekirdeğinden taşındı ve ana Linux yapısına uyarlandı (HDMI çıkış
bağlantıları ana Linux'un BeagleY-AI tarifindeki gibi). **22 Kasım'dan beri tek kaynak
`board/dts/`'dir**; Debian ve mainline çekirdekleri aynı dosyalardan derlenir
(`board/dts/README.md`):

| Dosya | İçerik | Debian | Mainline |
|---|---|---|---|
| `k3-am67a-t3-gem-o1-common.dtsi` (+ `-pinmux.dtsi`) | Görüntü dışındaki her şey | ✅ | ✅ |
| `k3-am67a-t3-gem-o1-display.dtsi` | DSS1, SiI9022 HDMI köprüsü, HDMI soketi, HDMI ses (McASP1), DSI | ✅ | — (mainline'da sürücü yok) |
| `k3-am67a-t3-gem-o1-gpu-v7.4.dtsi` | GPU ve VPU-SRAM düğümleri | — (yama 0023–0024 ile işlemci tarifinde) | ✅ (6.18'de yok) |

`board/dts/build-dtb.sh` bir `.dts`'i çekirdek ağacının işlemci `.dtsi` dosyalarına karşı derler,
ağaca hiçbir şey kopyalamaz. Kart tarifi değişince yalnızca DTB yeniden üretilir (saniyeler):
`DTB_ONLY=1 kernels/debian/build.sh`.

Açılış günlüğüne göre yapılan düzeltmeler (o zaman 0024 ve 0025 numaralı yamalardı):

| Değişiklik | Neden |
|---|---|
| Kullanılmayan R5 çekirdek kümeleri kapalı | "num_cores is set to 0" hatası ve "sync_state pending" uyarıları |
| HDMI ses kartı `playback-only` | HDMI'dan ses yalnızca dışarı çıkar. Ses sistemi (PipeWire) kayıt da deniyor ve her seferinde 3 hata satırı yazıyordu (açılışta ~360 satır). |
| Ethernet `phy-mode`: **`rgmii-rxid`** (kartta çalışan), `rgmii-id` denenmedi | Aşağıda |

**Ethernet ayarı ve 22 Kasım'da bulunan tutarsızlık:** Sürücü "RGMII mode without internal TX
delay unsupported" uyarısı veriyor ve `rgmii-id` öneriyor. 17 Kasım'da bu değişiklik yama olarak
eklenmişti (eski 0024), ama kartta denenmemişti. Yanlışsa Ethernet gider ve karta ağdan erişim
kopar. Bu yüzden `kernels/debian/out/` içindeki DTB elle `rgmii-rxid`'e geri alınmıştı; kart ve
yayın imajları bu DTB ile çalıştı. Yani `build.sh`'in kendisi kartta çalışan DTB'yi üretmiyordu
(üretseydi `rgmii-id` olurdu). Birleştirmede kartta çalışan değer (`rgmii-rxid`) kaynağa yazıldı;
`rgmii-id` §21.7'de ayrı bir deneme olarak duruyor. Yeni kaynaktan üretilen iki DTB eskileriyle
karşılaştırıldı: bütün düğüm ve özellikler aynı, yalnızca phandle numaraları (düğüm sırası) ve
T3'ün `base_dtb_timestamp` alanı farklı.

### 21.5 Nasıl derlenir?

```bash
kernels/debian/build.sh
```

Betik sırasıyla şunları yapar:

1. Debian'ın kaynak paketini (`.dsc`, `.orig.tar.xz`, `.debian.tar.xz`) indirir, Debian'ın kendi
   yamalarıyla açar ve git deposu yapar (`kernels/debian/src`, etiket `debian-7.2.12`).
2. `kernels/debian/patches/*.patch` dosyalarını `git am` ile uygular.
3. Debian'ın ayar dosyasını indirir, §21.3'teki değişiklikleri yapar.
4. `make bindeb-pkg` ile `.deb` paketini üretir ve `kernels/debian/out/`'a koyar; DTB'yi
   `board/dts/k3-am67a-t3-gem-o1.dts`'ten derler.

Kaynak bir kez hazırlandıktan sonra betik yalnızca derleme yapar. Kaynak yeniden hazırlanacaksa
`kernels/debian/src` silinir.

**Tekrarlanabilirlik:** Debian'ın ana sunucusu (`deb.debian.org`) backports'ta yalnızca en yeni
sürümü tutar; 7.2.13 çıktığında 7.2.12 dosyaları oradan silinir. Bu yüzden indirilen dört
dosyanın (kaynak paketi üç dosya + ayarın alındığı `linux-base` paketi) SHA-256 özeti
`versions.env`'de (`DEBIAN_KERNEL_PINNED`) sabit tutulur; `build.sh`: önce ana sunucuyu dener, dosya yoksa ya da özet tutmuyorsa aynı dosyayı
Debian'ın kalıcı arşivinden (`snapshot.debian.org/file/<sha1>`) indirir. Özet tutmayan dosya
kullanılmaz.

Çekirdeğin Debian'ın yeni bir sürümüne taşınması: `versions.env`'deki `DEBIAN_KERNEL_*` satırları
güncellenir, `kernels/debian/src` silinip betik çalıştırılır; uymayan yama olursa `git am` orada
durur.

Bu çekirdekle **yeni SD imajı** üretmek için `./build.sh image --flavor lite --kernel debian` (ya
da yalnız imaj adımı: `sudo ./go-pardus --kernel debian`). İmaj adına `-kdebian` eki gelir.
(`./build.sh desktop` 22 Kasım'dan beri 6.18 LTS + HDMI çekirdeğini kullanır, §27.) Çalışan bir kartı **SD
kartı yazmadan** güncellemek için §22.

Çekirdek seçenekleri (`--kernel`):

| Seçenek | Kaynak | HDMI | Durum |
|---|---|---|---|
| `t3` | T3'ün 6.12.24 çekirdeği (`scripts/02-kernel.sh`) | ✅ | ✅ çalışıyor |
| `debian` | Debian 7.2.12 + 24 yama (bu bölüm) | ✅ | ✅ çalışıyor; 22 Kasım'a kadar masaüstü çekirdeğiydi |
| `lts-hdmi` (varsayılan) | kernel.org 6.18 LTS + 20 HDMI yaması (§27) | ✅ | ✅ kartta çalışıyor, **masaüstü çekirdeği** |
| `mainline` | kernel.org **6.18 LTS**, **yamasız** (§24) | ❌ | ✅ kartta çalışıyor (22 Kasım), ekransız kullanım için |
| `ti` | TI'ın resmi çekirdeği | — | ⏳ hazırlanmadı |

### 21.6 Açılış günlüğü (dmesg): önce / sonra

"Önce" ilk çalışan Debian çekirdeği, "sonra" 17 Kasım 2026 derlemesi (Ethernet ayarı henüz eski).

| Sorun | Önce | Sonra | Ne yapıldı |
|---|---|---|---|
| Günlük uzunluğu | 1.285 satır | **671 satır** | — |
| SA2UL kripto çökmesi (Oops) + test hataları | Var | **Yok** | Sürücü kapatıldı |
| Ses "more channels than enabled" + ASoC hataları | 360 satır | **0** | `playback-only` |
| Ses "Sample-rate is off by … PPM" | 124 kez | 4 kez | Kayıt denemesi bitince azaldı; kalan için §21.7 |
| R5 "num_cores is set to 0" | 2 | **0** | Kümeler kapatıldı |
| "sync_state() pending" (CAN, JPEG, VPU, R5, fan) | 7 | **0** | Sürücüler eklendi, R5 kapatıldı |
| CAN "failed to get phy" | Var | **Yok**, CAN çalışıyor | CAN PHY sürücüsü |
| İmzasız modül / çekirdek kirli (taint) | E + W | **taint = 0** | Modül imzalama, Oops'un kalkması |
| DRM panic "qr_code" uyarısı | Var | **Yok** | `kmsg` |
| RGMII "TX delay" uyarısı | Var | Var | Düzeltme hazır, denenmedi |

Açılış süresi: 13,7 sn (çekirdek 5,9 sn + sistem 7,9 sn).

**Zararsız, dokunulmayanlar:**

| Mesaj | Anlamı |
|---|---|
| `j722s-c71_0-fw` yüklenemedi | Yapay zekâ hızlandırıcısının (C7x) firmware'i yoktu. ✅ 18 Kasım'da eklendi, iki DSP açılıyor (§23.4) |
| `HDMI: Unknown ELD version 0` | Bağlı monitör ses bilgisi (ELD) göndermiyor |
| `error retrieving port phy: -517` | Ethernet, PHY hazır olmadan bir kez denedi; ikinci denemede buldu |
| `of_irq_parse_pci: failed with rc=-22` | PCIe köprüsünün kesme tanımı; NVMe çalışıyor |
| `rtc-ds1307: unable to read the hardware clock` | Saat pili takılı değil |
| `bpf-restrict-fs: Failed to load BPF object` | systemd'nin isteğe bağlı bir özelliği; çekirdekte BPF LSM kapalı |
| `vdec … sram node not found` | Video çözücü ek SRAM'siz çalışıyordu. ✅ Yama 0024 (eski 0027) ile SRAM verildi |

### 21.7 Kalanlar

1. **Ethernet `rgmii-id`:** Kart tarifinde (`board/dts/k3-am67a-t3-gem-o1-common.dtsi`) ayar
   kartta çalışan `rgmii-rxid`; sürücünün önerdiği `rgmii-id` henüz denenmedi (§21.4). Yanlışsa
   Ethernet gider ve karta ağdan erişim kopar; bu yüzden ayrı bir adımda, seri konsol hazırken
   denenecek: satırı değiştirip `DTB_ONLY=1 kernels/debian/build.sh`, sonra DTB'yi karta
   göndermek. Geri dönüş: §22.6.
2. ~~**HDMI ses saati (PPM)**~~ ✅ 22 Kasım'da çözüldü: neden kart tanımındaki
   `auxclk-fs-ratio` ayarıydı; ses 48 kHz'te ~%8 yavaş çalıyordu. Ayrıntı ve çözüm §27.4.
3. **Debian'a bildirim:** Debian'ın arm64 ayarında TI K3 için kapalı olan parçalar (§21.3, ilk
   satırlar) için hata kaydı açılabilir.
4. **Overlay'ler (`.dtbo`) yok:** T3 çekirdeği kamera, DSI ekran ve AI uygulamaları için 35
   overlay üretiyor (§10). Debian çekirdeğinde bunlar henüz taşınmadı: `build.sh` yalnızca ana
   DTB'yi üretir, `03` boş overlay klasörünü siler, `05-kernel-deploy.sh` overlay'lere dokunmaz.
   Yani Debian çekirdekli imajda kamera/DSI overlay'i şu an kullanılamaz. Gerekirse T3'ün
   overlay kaynakları ana Linux yapısına uyarlanıp `board/dts/`'ye eklenmeli (`build-dtb.sh`
   `-@` ile derlediği için ana DTB overlay'e hazır).

---

## 22. Çekirdeği kartta güncellemek (SSH ile, SD kartı yazmadan)

### 22.1 Neden ayrı bir yol?

Normalde Debian'da çekirdek `apt upgrade` ile güncellenir. Bizde iki engel var:

1. Çekirdeğimiz Debian deposunda değil (kendi derlememiz). `apt`'nin onu görmesi için **kendi apt
   depomuz** gerekir (§22.7).
2. Kartın açılış yükleyicisi (U-Boot) çekirdeği `/boot`'tan değil, SD kartın **BOOT bölümünden**
   (FAT, 128 MB) okur. Paket kurulunca dosyaların BOOT'a da kopyalanması gerekir.

Bu yüzden şimdilik: çekirdek derleme makinesinde derlenir, SSH ile karta gönderilir, kartta küçük bir
betik paketi kurup dosyaları BOOT'a kopyalar.

### 22.2 Parçalar

| Parça | Nerede | Ne yapar |
|---|---|---|
| `scripts/05-kernel-deploy.sh` | Derleme makinesi | `.deb` ve DTB'yi karta gönderir, kurulumu başlatır, kartı yeniden başlatır, açılınca dmesg'i `kernels/<çekirdek>/dmesg-<tarih>.txt` olarak kaydeder. Çekirdek `KERNEL=lts-hdmi\|mainline\|debian` ile seçilir (varsayılan `lts-hdmi`; eski `.kernel` dosyası da okunur) |
| `board/gemstone-kernel-update` | Kartta `/usr/local/sbin/` (22 Kasım'dan beri imajda hazır) | Paketi kurar (`dpkg -i`), initramfs üretir, eski dosyaları yedekler, yenilerini BOOT'a kopyalar |
| `/etc/sudoers.d/gemstone-kernel-update` | Kartta | `pardus` kullanıcısının **yalnızca bu betiği ve `reboot`'u** şifresiz çalıştırmasına izin verir |
| SSH anahtarı | Derleme makinesi `~/.ssh/gemstone_board`, kartta `~pardus/.ssh/authorized_keys` | Şifresiz bağlantı |

Kurulunca BOOT'ta değişen dosyalar:

| BOOT'taki dosya | Nereden gelir |
|---|---|
| `Image` | `/boot/vmlinuz-<sürüm>` (paketten; gzip ise açılarak, §22.5.1) |
| `gemstone-image-rd-t3-gem-o1.cpio.gz` | `/boot/initrd.img-<sürüm>` (kartta `update-initramfs` üretir) |
| `k3-am67a-t3-gem-o1.dtb` | Gönderilen DTB, yoksa paketteki |
| `tiboot3.bin`, `tispl.bin`, `u-boot.img`, `uEnv.txt` | **Dokunulmaz** |

### 22.3 Kartta bir kerelik kurulum (root ile)

Derleme makinesinde anahtar üretilir ve karta eklenir:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/gemstone_board -C gemstone-board-deploy
ssh-copy-id -i ~/.ssh/gemstone_board.pub pardus@<kart-ip>
```

Kartta, sınırlı şifresiz `sudo` izni:

```bash
echo 'pardus ALL=(root) NOPASSWD: /usr/local/sbin/gemstone-kernel-update, /usr/sbin/reboot' | sudo tee /etc/sudoers.d/gemstone-kernel-update
sudo chmod 440 /etc/sudoers.d/gemstone-kernel-update
```

**22 Kasım'dan beri betiğin kendisi imajda hazır** (`/usr/local/sbin/gemstone-kernel-update`,
`03` kurar). Daha eski bir imajda betik önce karta kopyalanıp kurulur:
`scp board/gemstone-kernel-update pardus@<kart-ip>:` ve kartta
`sudo install -o root -g root -m 755 gemstone-kernel-update /usr/local/sbin/`. Şifresiz `sudo`
kuralı ise bilerek imaja konmaz: `pardus` için root'a eşdeğerdir (§22.8), yalnız geliştirme
kartlarında elle eklenir.

Aynı gün betikte bir hata da düzeltildi: BOOT'ta yer hesabında iki dosya adı arasında boşluk
eksikti, initramfs'in boyutu hesaba katılmıyordu (yer yetmese bile "yeter" diyebilirdi).

### 22.4 Kullanım

```bash
kernels/debian/build.sh                        # yeni çekirdek
scripts/05-kernel-deploy.sh 10.42.0.12         # karta gönder, kur, yeniden başlat, dmesg al

kernels/mainline/build.sh                      # ya da mainline çekirdek (§24)
KERNEL=mainline scripts/05-kernel-deploy.sh 10.42.0.12
```

⚠️ Masaüstlü bir karta mainline çekirdek kurulursa **HDMI görüntüsü gider** (mainline'da bu
işlemcinin görüntü desteği yok, §24). Kart ağdan erişilebilir kalır; geri dönmek için
`sudo gemstone-kernel-update --restore && sudo reboot`.

### 22.5 17 Kasım'da ne oldu: BOOT bölümü doldu

Betiğin ilk sürümü, eski dosyaları **BOOT bölümüne** `.prev` uzantısıyla yedekliyordu. Ama BOOT
128 MB ve Debian çekirdeği büyük:

| Dosya | Boyut |
|---|---|
| `Image` (çekirdek) | 52 MB |
| initramfs (Debian `initramfs-tools`, tüm modüllerle) | 37 MB |
| Bootloader dosyaları + DTB | 2,5 MB |
| **Toplam** | ~91 MB |

İkinci bir kopya sığmıyor. Yedekleme yarıda kaldı, bölüm %100 doldu, betik durdu. Çekirdek dosyaları
değiştirilmeden durduğu için **kart eski çekirdekle sorunsuz açıldı**. Sonrasında kart bilgisayara
takıldı; yarım yedek silindi ve yeni çekirdek, initramfs ve DTB elle BOOT'a yazıldı (eski dosyalar
derleme makinesinde `~/gemstone/boot-backup-20261117-0807/`). Kart yeni çekirdekle açıldı.

Betik düzeltildi:

- Yedekler artık BOOT'a değil, kök dosya sisteminde **`/var/backups/gemstone-boot/`** klasörüne.
- BOOT'ta kalmış eski `.prev` dosyaları silinir.
- Kopyalamadan önce yer hesabı yapılır; yetmiyorsa **hiçbir dosyaya dokunulmaz**.
- `gemstone-kernel-update --restore` ile önceki çekirdek geri konur.
- BOOT'ta ikinci kopyaya yer varsa dosya önce geçici adla (`*.new`) yazılır, sonra eskisinin
  üstüne yeniden adlandırılır. Kopyalama sırasında elektrik kesilirse kartta ya eski ya yeni
  dosya kalır, yarım dosya kalmaz.

⚠️ **Kalan risk:** Debian çekirdeğinde `Image` (52 MB) için BOOT'ta ikinci kopyaya yer yok
(boş alan ~35 MB). Bu durumda betik `Image`'ı yerinde ezer ve bunu ekrana yazar. Bu birkaç
saniyelik kopya sırasında elektrik kesilirse kart açılmaz ve `--restore` da çalıştırılamaz;
çözüm §22.6'daki SD kart yolu. Kalıcı çözüm seçenekleri (henüz denenmedi): yeni imajlarda BOOT
bölümünü büyütmek (ROM'un okuduğu FAT düzeni değişeceği için kartta doğrulanmalı) ya da
initramfs'i yalnızca bu kartın modülleriyle (`MODULES=dep`) küçültmek (SD kartın güç anahtarı
sürücüsü `gpio_regulator` dahil edilmeli, yoksa kart açılmaz).

Düzeltilmiş betik 18 Kasım'da kartta §22.3'teki `install` satırıyla kuruldu.

**Mainline çekirdekte bu risk yok:** `Image` 28 MB, initramfs 15 MB; BOOT'ta toplam 44 MB dolu,
~84 MB boş. Her dosyanın ikinci kopyasına yer olduğu için betik her zaman önce `*.new` yazar
(§24).

### 22.5.1 18 Kasım'da ne oldu: kart U-Boot'ta kaldı (sıkıştırılmış çekirdek)

GPU sürücüsünü ekleyen çekirdek SSH ile kurulduktan sonra kart yeniden başlayınca **U-Boot'ta
kaldı**, Linux açılmadı.

**Neden:** U-Boot'un `booti` komutu yalnızca **sıkıştırılmamış** arm64 çekirdeğini (`Image`) açar.
Paketin kurduğu `/boot/vmlinuz-<sürüm>` ise gzip ile sıkıştırılmış (`Image.gz`). Betik bu dosyayı
olduğu gibi BOOT'a `Image` adıyla kopyalamıştı. İlk kurulumda (17 Kasım) sorun çıkmamıştı çünkü
dosyalar elle, derleme makinesindeki sıkıştırılmamış `kernels/debian/out/Image`'dan yazılmıştı.

**Kurtarma:** SD kart bilgisayara takıldı, iki bölüm açıldı ve doğru `Image` derleme makinesinden
BOOT'a yazıldı. Kart açıldı.

**Betik düzeltmesi** (`board/gemstone-kernel-update`):

- `vmlinuz` gzip ise önce açılır (`gzip -dc`), BOOT'a sıkıştırılmamış hali yazılır.
- Yazmadan önce dosyanın gerçekten arm64 `Image` olduğu denetlenir: 56. bayttan itibaren `ARMd`
  imzası olmalı. Değilse **hiçbir dosyaya dokunulmaz** ve betik hata verir.

### 22.6 Bir şey ters giderse

| Durum | Ne yapılır |
|---|---|
| Kart açıldı ama yeni çekirdekte sorun var | Kartta `sudo gemstone-kernel-update --restore`, sonra `sudo reboot` |
| Kart açılmıyor / ağdan ulaşılamıyor | SD kartı bilgisayara takın. Linux'ta kök bölümdeki `/var/backups/gemstone-boot/` içindeki üç dosyayı BOOT'a kopyalayın. btrfs kök bölümü okuyamayan sistemlerde derleme makinesindeki yedekler ya da `kernels/debian/out/` kullanılır. |
| BOOT doldu | Kartta `df -h /boot/firmware`. `.prev` dosyaları silinebilir (yeni betik kendisi siler). |

### 22.7 Sonraki adım: `apt upgrade` ile güncelleme

Kalıcı çözüm bir apt deposu: çekirdek paketleri bir web sunucusunda imzalı depo olarak durur, kart
bu depoyu `sources.list`'e ekler. Pakete eklenecek küçük bir kurulum kancası
(`/etc/kernel/postinst.d/`) çekirdek, initramfs ve DTB'yi BOOT'a kopyalar. Böylece `apt upgrade` tek
başına yeterli olur. Deponun yeri (iç sunucu, GitHub Pages vb.) henüz belirlenmedi.

### 22.8 Güvenlik notu

Şifresiz `sudo` izni kâğıt üzerinde iki komutla sınırlı, ama **pratikte tam root yetkisine
eşdeğerdir**: `gemstone-kernel-update`, `pardus` kullanıcısının yazabildiği
`~/gemstone-update/` klasöründeki herhangi bir `.deb` paketini root olarak kurar ve bir paketin
kurulum betikleri (postinst) root olarak çalışır. Yani `pardus` hesabını ele geçiren biri kartta
root olur. Geliştirme kartında bilerek kabul ettiğimiz bir kolaylık; kart başkasına verilmeden,
ağa açılmadan ya da geliştirme bittiğinde kaldırılmalı:

```bash
sudo rm /etc/sudoers.d/gemstone-kernel-update /usr/local/sbin/gemstone-kernel-update
```

Kartın varsayılan şifresi de değiştirilmeli (`passwd`).

---

## 23. GPU (PowerVR) ve C7x DSP'ler

### 23.1 Kısaca

| Parça | Ne | Durum (kartta, 18 Kasım 2026) |
|---|---|---|
| GPU | Imagination **PowerVR BXS-4-64** | ✅ Vulkan çalışıyor (`vulkaninfo` GPU'yu görüyor) |
| C7x DSP × 2 | Yapay zekâ hızlandırıcısı (MMA'lı C7x) | ✅ İkisi de açılıyor (`remoteproc` "is now up"), TI'ın deneme firmware'iyle |
| Masaüstü | Xorg, XFCE | ✅ Hızlı; işlemciyle çiziliyor (§23.3) |

Hepsi **ana Linux'un kendi sürücüleriyle** çalışıyor; TI'ın kapalı GPU sürücüsü kullanılmıyor.

### 23.2 GPU için ne gerekti?

GPU'nun çalışması için dört parça gerekiyor. Debian 13'te hiçbiri tam değildi:

| Parça | Ne işe yarar | Nereden | Neden oradan |
|---|---|---|---|
| Çekirdek sürücüsü `drm/imagination` (`powervr.ko`) | GPU'yu çekirdekte yönetir | Ana Linux; Debian ayarında kapalıydı → `DRM_POWERVR=m` (§21.3) | — |
| Kart tarifinde GPU tanımı | Çekirdeğe GPU'nun adresini, saatini, güç alanını söyler | Ana Linux **7.4**'e giren TI yaması: Debian çekirdeğinde yama 0023, mainline 6.18'de `board/dts/k3-am67a-t3-gem-o1-gpu-v7.4.dtsi` | 7.4'ten önceki sürümlerde (6.18, 7.2, 7.3) yok |
| Firmware `powervr/rogue_36.53.104.796_v1.fw` | GPU'nun içinde çalışan küçük program | `ti-linux-firmware` (TI) | Debian 13'ün firmware paketlerinde bu sürüm yok |
| Kullanıcı alanı sürücüsü: Mesa ≥ 26 (PowerVR Vulkan) | Uygulamaların GPU'yu kullanması | Debian **trixie-backports**: Mesa 26.1.6 | Debian 13'teki Mesa 25.0.7 bu GPU'yu desteklemiyor |

Ayrıca kullanıcının **`render` grubunda** olması gerekir; yoksa Vulkan "permission denied" verir.
`03` artık `pardus` kullanıcısını bu gruba ekliyor.

**`03` ne yapıyor** ("2c" adımı, `.gpu-1` işaretiyle bir kez):

1. Firmware'i `/usr/lib/firmware/powervr/`'a koyar.
2. Masaüstlü boyutlarda (`full`, `lite`): trixie-backports deposunu ekler. Depo düşük öncelikle
   (100) eklenir; yani yalnızca açıkça istenen paketler oradan gelir, geri kalan her şey Pardus/
   Debian 13'ten gelmeye devam eder. Pardus'ta deponun imzası Debian'ın güncel anahtarlığıyla
   (`/usr/share/keyrings/gemstone-debian-archive.gpg`) doğrulanır.
3. Mesa paketlerini backports'tan kurar: `libgl1-mesa-dri libegl-mesa0 libglx-mesa0 libgbm1
   mesa-vulkan-drivers mesa-libgallium vulkan-tools mesa-utils`. Bu paketlerin güncellemeleri de
   oradan gelir.
4. Masaüstünü işlemci çizimine sabitleyen Xorg ayarını yazar (§23.3).

**Kartta kontrol:**

```bash
lsmod | grep powervr                       # sürücü yüklü mü
dmesg | grep -i powervr                    # "Initialized powervr" ve firmware sürümü
groups                                     # içinde render olmalı
vulkaninfo --summary | grep -i devicename  # PowerVR B-Series BXS-4-64 …
```

### 23.3 Masaüstü neden GPU ile çizilmiyor?

Mesa 26 kurulunca Xorg'un ekran sürücüsü (`modesetting`) masaüstünü GPU ile çizmeye (glamor)
çalıştı. Ama bu GPU'nun OpenGL sürücüsü yok; glamor, OpenGL'i Vulkan üzerinden taklit eden **zink**
katmanına düştü. Bu katman bu GPU'da henüz deneysel: **masaüstü çok yavaşladı, ölçek ve çizim
bozuldu** (18 Kasım'da kartta görüldü).

Çözüm: masaüstü eskisi gibi işlemciyle çizilir, GPU Vulkan uygulamalarına (ve yapay zekâ
çalışmalarına) açık kalır. `/etc/X11/xorg.conf.d/20-gemstone-noglamor.conf`:

```
Section "Device"
  Identifier "tidss"
  Driver "modesetting"
  Option "AccelMethod" "none"
EndSection
```

Bu dosya silinirse glamor yeniden açılır (Mesa'nın ileriki sürümlerinde denenebilir; denedikten
sonra Xorg yeniden başlatılmalı: `sudo systemctl restart lightdm`).

### 23.4 C7x DSP'ler

İşlemcideki iki C7x DSP, çekirdeğin `remoteproc` sürücüsüyle açılıyor. Çekirdek açılışta
`j722s-c71_0-fw` ve `j722s-c71_1-fw` adlı firmware'leri ister; bunlar yoktu ve dmesg'de
"failed to load" hatası çıkıyordu.

`03` şimdi TI'ın `ti-linux-firmware` içindeki **IPC deneme firmware'ini** (`ti-ipc/j722s/
ipc_echo_test_c7x_{1,2}_release_strip.xe71`) kurar ve çekirdeğin istediği adlarla bağlar
(sembolik bağ). TI'ın SDK'sı da aynısını yapıyor. Bu firmware yalnızca Linux ile DSP arasında
mesajlaşmayı sınar; **yapay zekâ modeli çalıştırmaz**. Gerçek uygulamada TI'ın TIDL/EdgeAI
firmware'i bu bağların yerine konur (§14 #6).

```bash
dmesg | grep -i c71                 # "remote processor … is now up"
cat /sys/class/remoteproc/*/state   # running
```

---

## 24. Mainline çekirdek (yamasız) ve `minimal` sistem

### 24.1 Kısaca

| | |
|---|---|
| **Çekirdek sürümü** | `6.18.64-gemstone-mainline` (`uname -r`) |
| **Paket** | `linux-image-6.18.64-gemstone-mainline_6.18.64-1gemstone1_arm64.deb` (20 MB) |
| **Kaynak** | kernel.org `linux-6.18.64.tar.xz` (**LTS**), SHA-256 özeti `versions.env`'de sabit; **hiçbir yama uygulanmaz** |
| **Destek** | kernel.org 6.18 LTS, tahmini bitiş **Aralık 2028** (kernel.org/category/releases.html, 22 Kasım 2026) |
| **Ayar** | Ana Linux'un genel arm64 ayarı (`defconfig`), TI dışındaki işlemci aileleri kapalı, kartın birkaç sürücüsü açık (§24.2) |
| **Kart tarifi** | `board/dts/k3-am67a-t3-gem-o1-headless.dts`: Debian çekirdeğiyle aynı ortak tarif, ekran/HDMI/ses parçaları olmadan + ana Linux 7.4'teki GPU ve VPU tanımları (§21.4) |
| **Boyut** | `Image` 26 MB (Debian çekirdeği 52 MB), 771 modül, initramfs 14 MB (Debian çekirdeğiyle 37 MB) |
| **HDMI** | ❌ Yok (§24.4) |
| **Betik** | `kernels/mainline/build.sh`, root gerekmez, 4 vCPU'da ~10 dk |
| **Çıktı** | `kernels/mainline/out/`: `.deb`, `Image`, `k3-am67a-t3-gem-o1.dtb`, `release` |
| **Kartta** | ✅ 22 Kasım: kart açıldı, GPU sürücüsü çalışıyor (§24.5) |

**Neden 6.18 LTS?** Bu seçenek önce güncel kararlı sürüm 7.3.5 ile kuruldu ve kartta açıldı. Ama
7.3 gibi kararlı seriler bir sonraki sürüm çıktıktan birkaç hafta sonra kapanır; güvenlik
güncellemesi uzun süre gelsin diye **uzun destekli (LTS)** seriye geçildi. kernel.org'un 22 Kasım
2026 listesi:

| LTS | Tahmini bitiş |
|---|---|
| **6.18** (seçilen, 6.18.64) | **Aralık 2028** |
| 6.12 | Aralık 2028 |
| 6.6, 6.1 | Aralık 2027 |
| 5.15, 5.10 | Aralık 2026 |

6.18 ile 6.12'nin bitişi aynı; 6.18 daha yeni olduğu için bu işlemciyi daha iyi tanıyor.

**6.18'de bu kart için neler var (derlemeden önce denetlendi):** işlemci tanımı (`k3-j722s.dtsi`
ve ortak AM62P/J722S dosyaları), kart tarifimizin kullandığı bütün düğümler (C7x, VPU, JPEG, R5,
SerDes, USB, PCIe, CAN, CPSW…), GPU sürücüsü (BXS-4-64 ve aynı firmware `rogue_36.53.104.796`),
`build.sh`'nin açtığı bütün sürücüler. GPU düğümü 6.18'de de yok (7.4'te geldi);
`board/dts/k3-am67a-t3-gem-o1-gpu-v7.4.dtsi` ile eklenir. LTS serisine yalnızca düzeltmeler girer,
yani 6.18.y'de bu dosya hep gerekecek.

**6.18 ile 7.3'ün DTB farkı:** yalnızca işlemcinin ortak dosyalarından gelenler: 7.3'te eklenen
yonga-özel uyumluluk adları (ör. `ti,j722s-cpsw-nuss`), kullanılmayan `main_i2c4` ve güvenlik
işlemcisi (HSM) düğümleri, ses saati düğümlerinin adı. Kart tarifimizin kendisinde fark yok.

**Güncelleme** (yeni 6.18.y çıkınca): `versions.env`'de `MAINLINE_VERSION`, `MAINLINE_SHA256`
(cdn.kernel.org `v6.x/sha256sums.asc`), `MAINLINE_PKGVER`; sonra `./build.sh headless
--rebuild-kernel` ve çalışan karta `KERNEL=mainline scripts/05-kernel-deploy.sh 10.42.0.12`.
Yeni yazılmış bir kartta `05`'ten önce §22.3'teki bir kerelik kurulum yapılır (SSH anahtarı ve
sınırlı `sudo` izni; güncelleme betiği imajda hazır). `apt upgrade` ile otomatik güncelleme için kendi apt
depomuz gerekir (§22.7).

**Amaç:** Ana Linux'ta olmayan **hiçbir şeye** bağlı olmayan bir çekirdek. Bedeli: HDMI yok, kart
ekransız (ağdan, SSH ile) kullanılır.

### 24.2 Ayar: neyi açtık, neyi kapattık?

`build.sh` sırasıyla:

| Adım | Ne | Neden |
|---|---|---|
| 1 | `make defconfig` | Ana Linux'un herkes için kullandığı arm64 ayarı |
| 2 | `arch/arm64/Kconfig.platforms` içindeki **`ARCH_K3` dışındaki** tüm işlemci aileleri kapalı | `defconfig`'teki modüllerin çoğu başka şirketlerin işlemcileri için; çekirdek küçülür, derleme hızlanır |
| 3 | `DRM_TIDSS`, `DRM_SII902X`, `SOUND`, `SND` kapalı | Görüntü birimi ana Linux'ta bu işlemcide çalışmıyor; HDMI ses de ona bağlı |
| 4 | Sunucu/PC ekran kartı ve ağ kartı sürücüleri kapalı (nouveau, amdgpu, radeon, mlx4/5, ixgbe, igb, e1000e, bnx2x, chelsio, hns3) | Kartta PCIe yuvası var ama bunlar gerçekçi değil; gerekirse açılır |
| 5 | btrfs (**çekirdeğe gömülü**), SD/eMMC (`MMC_SDHCI_AM654`), güç yongası TPS65219 ve güç düğmesi, GPU (`DRM_POWERVR`) | Kök dosya sistemi btrfs; initramfs'e modül eklemeden açılsın |
| 6 | Wi-Fi/BT (RTL8822CS: `RTW88_8822CS`, `BT_HCIUART_RTL`, `3WIRE`) | Kartın kablosuz yongası |
| 7 | Ethernet (CPSW, MDIO, DP83867 PHY), CAN (`M_CAN` + `PHY_CAN_TRANSCEIVER`), nem sensörü HDC2010, fan PWM, watchdog, C7x/R5 `remoteproc`, video (Wave5 VPU), JPEG kodlayıcı (E5010), PCIe (J721E), USB (CDNS3), RTC | Kartın donanımı; `defconfig`'te olmayanlar |
| 8 | systemd ve Debian `initramfs-tools`'un istedikleri (devtmpfs, initrd, gzip/zstd, cgroups, autofs, tmpfs ACL, seccomp) | Pardus'un açılması için |
| 9 | Hata ayıklama bilgisi kapalı, sürüm eki `-gemstone-mainline` | Küçük paket; diğer çekirdeklerden ayırt edilsin |

Sonuç (6.18.64): 631 modül, 2.055 gömülü seçenek (ayar dosyasında; paket 771 `.ko` dosyası
içeriyor). 7.3.5'te 713 / 1.966 / 852 idi.

**Kaynağa dokunulmaz.** Kart ana Linux'ta olmadığı için tarifini (DTS) ağaca koymak gerekirdi;
bunun yerine `build.sh` DTS'i ağacın **dışında**, ağacın kendi `.dtsi` dosyalarına karşı `cpp` +
`dtc` ile derler. Ağaç kernel.org'dan geldiği gibi kalır.

**Yarım açılmış kaynak koruması:** Kaynak arşivi önce geçici bir klasöre açılır, bitince yeniden
adlandırılır. 21 Kasım'da VM derleme sırasında donunca kaynak yarım açılmış kaldı (başlık dosyaları
0 bayt) ve derleme anlamsız bir bağlama hatası verdi; bu koruma o yüzden eklendi.

### 24.3 `minimal` sistem

| | `minimal` |
|---|---|
| Ne var | Pardus 25 tabanı (`os-release`: Pardus 25.2), Türkçe yerel ayar, SSH, NetworkManager (sabit IP `10.42.0.12`), Wi-Fi/BT firmware'i, kart araçları (`i2c-tools`, `spi-tools`, `gpiod`, `can-utils`, `ethtool`, `usbutils`, `pciutils`, `v4l-utils`, `alsa-utils`), Python 3 (`python3-libgpiod`, `python3-smbus2`), GPU ve C7x firmware'i |
| Ne yok | Masaüstü, Xorg, Mesa, ses sunucusu, geliştirme araçları, belgeler, fazla diller |
| Açılış hedefi | `multi-user.target` (metin konsolu) |
| Kapalı zamanlayıcılar | `apt-daily`, `apt-daily-upgrade`, `man-db`, `e2scrub_all`, `NetworkManager-wait-online` |
| Ölçüler | 285 paket, rootfs ~500 MB (firmware 32 MB), BOOT 42 MB, ham imaj 4 GB, `.xz` 181 MB |
| Seçmek için | `./build.sh headless` ya da `--flavor minimal` (çekirdekten bağımsız; T3 ya da Debian çekirdeğiyle de olur) |

`minimal` ile mainline çekirdek iyi bir çift: ikisi de ekranı kullanmıyor. Ama birbirine bağlı
değiller; `minimal` + `debian` ya da `lite` + `mainline` de üretilebilir (ikincisinde masaüstü
kurulur ama HDMI'dan görüntü gelmez).

### 24.4 Neden HDMI yok, ne zaman gelir?

Kartın HDMI'ı işlemcinin görüntü birimine (DSS) bağlı ve ana Linux bu işlemcinin görüntü birimini
henüz tanımıyor (§20.3). Destek, Tomi Valkeinen'in yamalarıyla gelecek (§21.2, yamalar 0001–0022);
bu yamalar kabul edilmedi. Mainline kart tarifinde bu yüzden görüntü birimi, HDMI köprüsü
(SiI9022), HDMI ses kartı, McASP1 ve DSI parçaları yok. Yamalar ana Linux'a girdiğinde:

1. Mainline kart tarifine bu parçalar geri eklenir (Debian kart tarifinde hazır duruyor).
2. `build.sh`'de `DRM_TIDSS`, `DRM_SII902X` ve ses yeniden açılır.
3. Debian çekirdeğine gerek kalmaz; masaüstü de yamasız çekirdekle çalışır.

Takip: https://lore.kernel.org/dri-devel/?q=am62p+dss

### 24.5 Kartta deneme

**22 Kasım:** İlk sürüm (7.3.5 çekirdekli `minimal` imaj) karta yazıldı ve **kart açıldı**. Ardından
uzun destek için çekirdek 6.18 LTS'e çevrildi; **6.18'li imaj da aynı gün kartta açıldı, GPU dahil
çalıştı.**

**Ölçüm (22 Kasım, `minimal` + 6.18.64, kartta):**

| | Sonuç |
|---|---|
| `uname -r` | `6.18.64-gemstone-mainline` |
| Açılış | **15,0 s** (çekirdek 3,3 s + sistem 11,7 s, `multi-user.target`) — Debian çekirdekli masaüstü 13,7 s / lite ilk sürüm 24 s |
| Boşta bellek | **298 MB** kullanılıyor / 3,7 GB (3,4 GB kullanılabilir) |
| GPU | ✅ `powervr fd80000.gpu`: firmware `rogue_36.53.104.796_v1.fw` yüklendi, `Initialized powervr 1.0.0` |
| C7x DSP × 2 | ✅ ikisi de `running` |
| Wi-Fi sürücüsü | ✅ `rtw88_8822cs` yüklü |
| CAN | ✅ `m_can_platform` yüklü |
| Ethernet | ✅ SSH ile bağlanıldı |

dmesg'deki uyarılar (hepsi bilinen ya da zararsız):

| Mesaj | Anlamı |
|---|---|
| `KASLR disabled due to lack of seed` | U-Boot çekirdeğe rastgele sayı tohumu vermiyor; çekirdek adresi rastgeleleştirilmiyor. Güvenlik iyileştirmesi olarak ileride U-Boot'ta açılabilir |
| `ITS … Devices Table too large, reduce ids 20->19` | Kesme denetleyicisinin tablo boyutu kendiliğinden küçültüldü; bilgi |
| `sdhci-am654 … card claims to support voltages below defined range` | SD kartın kendi bildirdiği gerilim aralığı; kart çalışıyor |
| `RGMII mode without internal TX delay unsupported` | Bilinen; `rgmii-rxid` ayarı (§21.4, §21.7) |
| `rtc-ti-k3 … Clock rate 32552 is not 32768` | İşlemcinin iç saatinin (RTC) besleme saati tam 32768 Hz değil; saat NTP ile düzeltiliyor |
| `rtc-ds1307 … unable to read the hardware clock` | Kart üstü saatin pili takılı değil (Debian çekirdeğinde de var) |
| `of_irq_parse_pci: failed with rc=-22` | PCIe köprüsünün kesme tanımı (Debian çekirdeğinde de var); NVMe çalışıyor |

Kart ekransız açıldığı için açılış Ethernet'ten izlenir (§13.2.1):

1. İmajı karta yazın (§25.2). PC'nin Ethernet adresi `10.42.0.11/24`.
2. Güç verin; ~30 sn sonra `ping 10.42.0.12`, ardından `ssh pardus@10.42.0.12`.
3. Kontrol:

```bash
uname -r                          # 6.18.64-gemstone-mainline
systemd-analyze; free -h          # açılış süresi, bellek
dmesg --level=err,warn            # hatalar
ip -br addr                       # Ethernet arayüzü ve 10.42.0.12
sudo ethtool <arayüz> | grep Speed  # 1000Mb/s beklenir
lsmod | grep -E 'powervr|rtw88|m_can|hdc2010'
cat /sys/class/remoteproc/*/state
```

**Riskler:**

| Risk | Belirti | Ne yapılır |
|---|---|---|
| Ethernet açılmaz (kart tarifinde `rgmii-rxid`; ana Linux sürücüsü bu ayara Debian 7.2'dekinden farklı davranabilir) | Ping yok ama U-Boot'un ARP işaretleri Wireshark'ta görünüyor | Seri konsol (UART, 115200) ile bakılır; gerekirse `rgmii-id` denenir (§21.7) |
| Kart açılmaz | ARP işaretlerinden sonra hiçbir şey | SD kartı geri alın; seri konsol gerekir. Eski imaj yeniden yazılır |

### 24.6 Debian çekirdeğiyle karşılaştırma

| | `debian` (§21) | `mainline` (bu bölüm) |
|---|---|---|
| Kaynak | Debian 7.2.12 + Debian'ın yamaları | kernel.org 6.18 LTS, yamasız |
| Destek | kernel.org'da 7.2 serisi kapandı (7.2.15 EOL); güncelleme, Debian'ın yeni çekirdek paketine taşıyıp yamaları yeniden uygulamakla | kernel.org 6.18.y, **Aralık 2028'e kadar** |
| Bizim yamalarımız | 24 (HDMI, GPU/VPU) | **0** (kart tarifi ağacın dışında) |
| Ayar | Debian'ın tam ayarı + ekler | `defconfig` + yalnızca TI K3 + ekler |
| `Image` / initramfs | 52 MB / 37 MB | **26 MB / 14 MB** |
| BOOT'ta yedek kopyaya yer | Yok (§22.5) | Var |
| HDMI, HDMI ses | ✅ | ❌ |
| GPU (Vulkan) | ✅ | Sürücü ve tanım var; Mesa yalnızca masaüstlü boyutlarda kurulu |
| Kartta denendi | ✅ | ✅ (22 Kasım) |
| Önerilen kullanım | Masaüstü | Ekransız: sunucu, sensör, yapay zekâ çalıştırıcı |

---

## 25. Yayın imajları ve seçenekler

### 25.1 İmajlar

İki imaj yayınlanacak biçimde üretildi (22 Kasım 2026, `./build.sh desktop|headless --release
2026.11`, `xz -6`). Her birinin yanında bir `.sha256` dosyası var. ARM kartlar için kurulum
ISO'su olmaz: imaj doğrudan SD karta yazılır ve kart ondan açılır.

İçerik 18 ve 21 Kasım imajlarıyla aynı paketler, aynı çekirdekler ve eşdeğer DTB'dir; farkları:
derlemenin durum dosyaları imaja girmiyor ve sıkıştırma daha sıkı (`-6`; masaüstü 634 → 616 MB,
ekransız 195 → 190 MB, ~%3; ekransız imaj sonra 6.18 LTS çekirdeğiyle yeniden üretildi).

| | Masaüstü | Ekransız |
|---|---|---|
| Dosya | `t3-gem-o1-pardus-yirmibes-arm64-lite-20261122-own-klts-hdmi.img.xz` | `t3-gem-o1-pardus-yirmibes-arm64-minimal-20261122-own-kmainline.img.xz` |
| Boyut (`.xz` / açılmış) | 443.872.548 bayt (423 MB) / 8 GB | 190.208.544 bayt (181 MB) / 4 GB |
| SHA-256 (`.xz`) | `22fab4278e389e9285e2e377e0cda6bed51e17690af18b37815fbdc5e7ac2ed8` | `fb13963e6d1e8bc85ff4aa25e18a0d1dd59ad6fdfdb0b41759b0ca402ba7040e` |
| SHA-256 (`.img`) | `38e060d43dd476f7b924534aa1b8bae9f63fa9ae68a9e1b7e6e0971bb486d1b7` | `d74b55f2bc2414cb544731389c4ee140df4f74f89fc7b96e57dd9d1a9a1332e5` |
| Sistem | Pardus 25.2, sade XFCE (`lite`), 788 paket | Pardus 25.2, masaüstüsüz (`minimal`), 285 paket |
| Çekirdek | `6.18.64-gemstone-hdmi+` (6.18 LTS + 20 HDMI yaması, §27) | `6.18.64-gemstone-mainline` (6.18 LTS, yamasız) |
| HDMI / ses | ✅ / ✅ | ❌ / ❌ |
| GPU | ✅ Vulkan (Mesa 26.1.6) | Firmware var, Mesa yok |
| Kartta denendi | ✅ HDMI görüntü, giriş ekranı, masaüstü; ses sürücüsü hatasız (§27.4) | ✅ imajın kendisi karta yazılıp açıldı (22 Kasım), GPU çalışıyor |

Ortak: bootloader, initramfs, Pardus kurulumu bizim (`-own`); kullanıcı `pardus` / `temppwd`
(ilk girişte yeni şifre istenir); sabit IP `10.42.0.12/24`; ilk açılışta kök bölüm SD kartın
tamamına büyür; SSH anahtarları ilk açılışta her kart için yeniden üretilir; çekirdek güncelleme
betiği `/usr/local/sbin/gemstone-kernel-update` hazır (şifresiz `sudo` kuralı yok, §22.3).

Son üretim 22 Kasım 12:35–12:40 (güncelleme betiği eklendikten sonra). Kartta denenen ekransız imaj
bundan bir önceki üretimdi: aynı çekirdek ve sistem, yalnızca betik yoktu.

Yayın klasörü derleme makinesinde **`~/gemstone/release/2026.11/`**: iki `.img.xz`, her birinin
`.sha256`'sı, ortak `SHA256SUMS`, `SURUM-NOTLARI.md` (dağıtılacak kısa metin, kaynağı
`docs/SURUM-NOTLARI.md`) ve `BUILDINFO.txt` (git commit'i, imaj özetleri, sabit sürümler).
İmaj dosyaları `out/`'takilere sabit bağlantıdır (hard link), ikinci kez yer tutmaz.

### 25.2 İndirip karta yazma

```bash
sha256sum -c t3-gem-o1-…img.sha256      # .img ve .img.xz aynı klasörde; .xz satırı "OK" demeli
```

(`.img` satırı, imaj açılmadıysa "No such file" der; bu normaldir.)

Yazma: balenaEtcher ya da Raspberry Pi Imager `.img.xz` dosyasını doğrudan yazar. Linux'ta
`sudo ./scripts/04-flash-sd.sh /dev/sdX release/2026.11/<dosya>.img.xz` (açmadan yazar, önce
özeti denetler, sonra geri okuyup karşılaştırır; §13.1). SD kart en az 8 GB (masaüstü) / 4 GB
(ekransız) olmalı; 16 GB ve üstü önerilir.

### 25.3 Bütün seçenekler

İmaj üç bağımsız seçimle üretilir. `./build.sh image --flavor … --kernel …` ya da doğrudan
`03`'ün komut satırı seçenekleri (öncelik: komut satırı > ortam değişkeni > eski işaret
dosyası > varsayılan):

| Seçim | Seçenek (eski işaret dosyası) | Değerler | İmaj adındaki eki |
|---|---|---|---|
| Sistem boyutu | `--flavor` (`.flavor`, `.lite`) | `lite` (varsayılan), `full`, `minimal` | `-lite-`, `-full-`, `-minimal-` |
| Çekirdek | `--kernel` (`.kernel`) | `lts-hdmi` (varsayılan), `mainline`, `debian`, `t3` | `-klts-hdmi`, `-kmainline`, `-kdebian`, (yok) |
| Açılış zinciri | `--vendor-bl`, `--vendor-initrd` (`.vendor-*`) | yok = bizim (önerilen); varsa T3'ün dosyaları | `-own`, `-vbl`, `-vinitrd`, `-vboot` |
| Dağıtım | `--distro` | `pardus` (`build.sh`, `go-pardus`), `debian` (`03` tek başına, `go`) | `-pardus-yirmibes-`, `-debian-trixie-` |
| Sıkıştırma | `--xz N` (`build.sh --release` = 6) | 0–9, varsayılan 3 | — |

`build.sh`'in kısayolları: `desktop` = `lite` + `debian`, `headless` = `minimal` + `mainline`.
22 Kasım'a kadar `03`'ün varsayılanı `full` + `t3` idi; önce `lite` + `debian`, HDMI 6.18'de kartta çalışınca `lite` + `lts-hdmi` yapıldı.

Her boyutun ayrı rootfs klasörü vardır (`build/rootfs-pardus-yirmibes[-lite|-minimal]`); biri
üretilirken diğerleri bozulmaz. Çekirdek değişince rootfs'teki eski çekirdek paketi ve modülleri
silinir, yenisi kurulur (rootfs'te hep tek çekirdek).

Yayın imajlarını yeniden üretmek:

```bash
./build.sh headless --release 2026.11
./build.sh desktop  --release 2026.11
```

İmaj adındaki tarih derleme günüdür; aynı kaynaklardan bugün üretilen imaj, Pardus/Debian
depolarındaki paketler o arada güncellendiyse birebir aynı olmaz.

### 25.4 Bilinen sorunlar (sürüm notunda da var)

| Sorun | İmaj | Geçici çözüm |
|---|---|---|
| Ekran karardıktan sonra görüntü geri gelmiyor (§14 #12) | Masaüstü | XFCE Güç Yöneticisi'nde ekran karartma/DPMS kapatılır |
| HDMI ses örnekleme hızı %0,8 kayık (dmesg'de "PPM" mesajı) (§21.7) | Masaüstü | Ses çalışıyor; dokunulmadı |
| Ethernet ayarı `rgmii-rxid`, dmesg'de "TX delay" uyarısı (§21.7) | İkisi | Ethernet çalışıyor (masaüstü); ekransızda denenmedi |
| Kamera/DSI overlay'leri yok (§21.7 #4) | İkisi | T3 çekirdeğiyle imaj üretilir |
| Varsayılan şifre (`temppwd`) herkesçe biliniyor; SSH şifreyle girişe açık | İkisi | İlk girişte şifre değişimi zorunlu; kart başka bir ağa bağlanmadan önce ilk giriş yapılıp şifre değiştirilmeli |
| Masaüstü GPU ile çizilmiyor (§23.3) | Masaüstü | Bilerek; GPU Vulkan'a açık |

---

## 26. Betiklerin düzeni (22 Kasım 2026)

### 26.1 Tek komut: `build.sh`

```bash
./build.sh desktop                 # lite + Debian çekirdeği
./build.sh headless                # minimal + mainline çekirdek
./build.sh image --flavor full --kernel t3
./build.sh desktop --release 2026.11
```

Normal kullanıcıyla çalışır (root ile çalıştırılırsa durur). Dört adım; sonucu olan adım atlanır:

| Adım | Atlanır, eğer | Çalıştırdığı |
|---|---|---|
| 1. Kaynaklar | derleyici, `u-boot/`, `ti-linux-firmware/` var | `scripts/00-fetch-sources.sh` |
| 2. Bootloader | `out/boot/{tiboot3.bin,tispl.bin,u-boot.img}` var | `scripts/01-bootloader.sh` |
| 3. Çekirdek | `kernels/<ad>/out/linux-image-*.deb` var (`--rebuild-kernel` zorlar). Atlansa da DTB `board/dts/`'den yeniden üretilir | `kernels/<ad>/build.sh` ya da `scripts/02-kernel.sh` |
| 4. Sistem + imaj | — (her seferinde) | `sudo scripts/03-rootfs-image.sh --distro … --flavor … --kernel … --xz …` |
| (5. Yayın) | yalnız `--release` ile | `scripts/06-release.sh <sürüm> <imaj>` |

Seçimler `03`'e **komut satırından** geçer. Eskiden `sudo` ortam değişkenlerini sildiği için
seçimler deponun klasöründeki `.flavor` / `.kernel` dosyalarına yazılıyordu; bu dosyalar
unutulunca sonraki derleme farkında olmadan başka bir birleşim üretiyordu (21 Kasım'da `.lite`,
`.flavor` ve `.kernel` aynı anda duruyordu). `03` eski dosyaları hâlâ okur ama komut satırı önce
gelir. Derleme makinesindeki şifresiz `sudo` kuralı `03`'ün yolunu kapsadığı için seçenekler de
kapsanır.

### 26.2 Neler değişti

| | Önce | Sonra |
|---|---|---|
| Başlatma | 5–6 komut + işaret dosyaları | `./build.sh desktop` |
| Kart tanımı | Debian: yama 0023–0025; mainline: `kernels/mainline/dts/` (iki kopya). Debian çıktısındaki DTB elle düzeltilmişti | Tek kaynak `board/dts/`, iki çekirdek için `build-dtb.sh`; `DTB_ONLY=1` ile saniyeler (§21.4) |
| Sürümler | `00`, `kernels/debian/build.sh`, `kernels/mainline/build.sh`, `01`, `02` içine dağılmış | `versions.env` |
| `03` seçenekleri | ortam değişkeni ya da işaret dosyası | `--flavor`, `--kernel`, `--distro`, `--vendor-*`, `--xz`, `--help` |
| `03` varsayılanı | `full` + `t3` | `lite` + `debian`; aynı gün `lite` + `lts-hdmi` (§27) |
| `03` denetimleri | — | Çekirdek paketi `release` dosyasıyla aynı derlemeden mi (değilse initramfs başka modüller için üretilirdi) |
| `03` içi | chroot'a giriş/çıkış 4 yerde ayrı ayrı yazılmış | `chroot_up` / `chroot_down` |
| İmaj içeriği | derlemenin durum dosyaları (`/.kernel-deb`, `/.gpu-1`, `/.slim-1`) imajın kökünde | imaja girmiyor |
| `04` | yalnız `.img`, hep en yeni imaj | `.img.xz` açmadan yazılır, imaj adla seçilir, yazmadan önce `.sha256` denetlenir |
| Yayın | elle | `06-release.sh`: `release/<sürüm>/` + `SHA256SUMS` + `BUILDINFO.txt` |
| `go-pardus`, `go` | yalnız işaret dosyası | seçenekleri `03`'e geçirir |

### 26.3 Doğrulama

| Ne | Nasıl | Sonuç |
|---|---|---|
| Betiklerin sözdizimi | `bash -n` (hepsi) | ✅ |
| Kart tanımı | Yeni kaynaktan iki DTB üretilip eskileriyle karşılaştırıldı (`dtc -s`, sayılar maskeli) | ✅ fark yok (yalnız phandle numaraları, T3'ün zaman damgası) |
| GPU/VPU yamaları | Yeni adlar (0023, 0024) git'teki eski 0026, 0027 ile bayt bayt | ✅ aynı |
| `build.sh` + `03` + `06` | İki yayın imajı baştan sona yeni betiklerle üretildi | ✅ `BUILD_OK`, `RELEASE_OK`, `SHA256SUMS` "OK" |
| `04` imaj seçimi | `sudo 04 /dev/olmayan minimal` ve `.img.xz` yoluyla | ✅ doğru imajı seçti, özet OK, aygıt yok diye durdu |
| Kartta | Ekransız imaj (6.18 LTS) `04` ile `.img.xz`'den karta yazıldı ve açıldı | ✅ (masaüstü imajı karta yazılmadı) |

Sonradan denenenler: `04`'ün `.xz`'den gerçek bir karta yazması ✅, `--rebuild-kernel` ✅ (6.18
LTS geçişinde). Denenmeyen: `./build.sh` ile sıfırdan (kaynaklar dahil) kurulum.

### 26.4 Temizlik (22 Kasım)

| Silinen | Neden | Kazanılan |
|---|---|---|
| 9 eski imajın açılmış `.img`'si (6–17 Kasım) | `.img.xz` + `.sha256` duruyor | ~21 GB |
| `kernels/build-debian.sh`, `kernels/patches/`, `kernels/netconsole/` | Debian çekirdeğinin ilk denemeleri, yerini `kernels/debian/` aldı | 37 MB |
| `CORTEXA/`, `input/` | 5 Kasım'daki ilk elle U-Boot denemesi, boş klasör | 3 MB |
| `.lite`, `.flavor`, `.kernel` | İşaret dosyaları; seçimler artık komut satırında | — |
| `kernels/mainline/dts/`, yamalar 0023–0025 (depodan) | `board/dts/`'ye taşındı | — |
| 7.3.5 kaynak arşivi ve derleme klasörü, 7.3.5'li ekransız imajlar (21 ve 22 Kasım), 18 Kasım masaüstü imajı, kartın `/home` yedeği | 6.18 LTS'e geçildi; masaüstü imajının yerini 22 Kasım'ınki aldı | ~2 GB |

Kalan (root'a ait, betikler silemiyor): `build/rootfs-trixie/` (Debian 13 kök dosya sistemi,
6 Kasım'dan beri kullanılmıyor). Silmek için: `sudo rm -rf ~/gemstone/build/rootfs-trixie`.
Eski imajların (6–17 Kasım) yalnızca `.img.xz` + `.sha256`'ları `out/`'ta duruyor.

---

## 27. Masaüstü de LTS'te: 6.18 + HDMI yamaları (`lts-hdmi`, deneme)

### 27.1 Neden?

Masaüstü imajının çekirdeği Debian'ın 7.2.12'si (§21). kernel.org'da 7.2 serisi kapandı; güvenlik
güncellemesi için Debian'ın yeni bir çekirdek paketine geçip HDMI yamalarını her seferinde yeniden
uygulamak gerekiyordu. Ekransız imajın çekirdeği ise 6.18 LTS (§24), Aralık 2028'e kadar
düzeltme alıyor. Amaç: masaüstünü de aynı 6.18 LTS kaynağına taşımak; tek fark HDMI yamaları olsun.

### 27.2 Yamaları 6.18'e taşımak (22 Kasım)

Debian serisinin 22 HDMI yaması (0001–0022) 6.18.64'e sırayla uygulandı:

| Sonuç | Sayı | Yamalar (Debian numarası) |
|---|---|---|
| Olduğu gibi uydu | 15 | 0001, 0004–0011, 0013, 0014, 0017–0019, 0021 |
| Elle uyarlandı | 5 | 0002 (düğüm adı başka dosyada), 0015 ve 0016 (kutup/`DPIENABLE` ayarları 6.18'de `dispc_vp_enable()` içinde), 0020 (`dss_oldi_io_ctrl` düğümünün yeri), 0022 (`atomic_check`, 6.18'in işlev imzasıyla) |
| Bilerek atlandı | 2 | 0003 (yalnız AM62; düğümü 6.18'de yok), 0012 (yinelenen bir çağrının temizliği; 6.18'de tutmak güvenli) |

Uyarlamaların hiçbirinde yeni kod yazılmadı; 6.18 ile 7.2 arasında yeri değişen kodun yeni yerine
konuldu. Sonuç 20 yama. Yama yama karşılaştırma ve her uyarlamanın 7.2'deki / 6.18'deki yeri:
`docs/HDMI-YAMALARI.md` (kısa liste: `kernels/lts-hdmi/patches/README.md`).

Yeniden üretilebilirlik (22 Kasım): iki seriden de gereksiz bir `tidss_oldi.c.rej` dosyası
(reddedilmiş parça kaydı; bir yama ekleyip diğeri siliyordu) çıkarıldı; ardından 6.18 serisi temiz
6.18.64 kaynağına baştan uygulandı ve çekirdeğin derlendiği ağacın dosya dosya aynısını verdi.

### 27.3 Derleme

| | |
|---|---|
| Betik | `kernels/lts-hdmi/build.sh` (= `VARIANT=hdmi kernels/mainline/build.sh`) |
| Kaynak | aynı `linux-6.18.64.tar.xz` (`versions.env`), git ağacı + 20 yama |
| Ayar | ekransız çekirdekle aynı (§24.2), üstüne: `DRM_TIDSS`, `DRM_SII902X`, `DRM_DISPLAY_CONNECTOR`, `PHY_CADENCE_DPHY`, ses (`SND_SOC_DAVINCI_MCASP`, UDMA/EDMA/SDMA PCM, `SND_SIMPLE_CARD`, `SND_SOC_HDMI_CODEC`, `SND_USB_AUDIO`), HDMI'da metin konsolu |
| Kart tanımı | `board/dts/k3-am67a-t3-gem-o1-lts-hdmi.dts` = ortak + ekran + GPU (v7.4) |
| Sürüm | `6.18.64-gemstone-hdmi+` |
| Sonuç | `Image` 26 MB, 732 modül (ayar dosyasında; paket 871 `.ko` içeriyor), DTB 99 KB, derleme 11 dk (4 vCPU) |
| Denetlendi | pakette `tidss`, `sii902x`, `display-connector`, McASP/simple-card/hdmi-codec ses modülleri, `powervr`; `tidss` `ti,am62p-dss`'i tanıyor; DTB'de `ti,am62p-dss`, `sil,sii9022`, `hdmi-connector`, `simple-audio-card`, GPU düğümü, `rgmii-rxid` |

İmaj: `./build.sh image --flavor lite --kernel lts-hdmi` → `…-lite-AAAAGGAA-own-klts-hdmi.img`.

### 27.4 Kartta (22 Kasım)

✅ **HDMI'dan görüntü geldi**, Pardus giriş ekranı ve XFCE masaüstü açıldı. Masaüstü imajı bu
çekirdeğe geçti: `./build.sh desktop` = `lite` + `lts-hdmi`, `03`'ün varsayılan çekirdeği
`lts-hdmi`. Debian 7.2.12 çekirdeği (`kernels/debian`) seçenek olarak duruyor, yayında değil.

Denemede çıkan üç sorun ve çözümü:

| Belirti | Neden | Çözüm |
|---|---|---|
| Giriş ekranı açılırken `FileNotFoundError: 'xset'` | Benim temizlik adımım (`.slim-2`) `cpp`'yi kaldırırken ona bağlı `x11-xserver-utils`, `xfce4-session`, `pardus-xfce-settings` paketlerini de kaldırdı | Temizlik artık her paketi önce simüle ediyor; başka bir şey götürecekse bırakıyor (`cpp` kalır). Paketler geri kuruldu, eksik bağımlılık 0 |
| Ses ~%8 yavaş ve kalın (Debian çekirdeğindeki "off by … PPM" de bu) | Kart tanımındaki `auxclk-fs-ratio = <2177>` (T3 ve BeagleY-AI'den gelen) sürücüye "AUXCLK = 2177 × örnekleme hızı" diyor; bu yalnız 44,1 kHz'te doğru (96 MHz / 2177). PipeWire'ın 48 kHz'inde sürücü 104,5 MHz sanıp yanlış bölen seçiyordu | Oran kaldırıldı; ses kartının işlemci tarafına gerçek frekans yazıldı: `system-clock-frequency = <96000000>`. Sürücü artık her hızın gerçek hatasını hesaplayıp yalnız tutturabildiklerini sunuyor (44,1 kHz ve katları); PipeWire 44,1 kHz açıp dönüştürüyor. Kartta: "off by 400 PPM" (%0,04) |
| dmesg'de sürekli "stream has more channels (2) than are enabled in mcasp (0)", ASoC error -22 | Ses sunucusu HDMI'dan kayıt açmayı deniyor; McASP'ta giriş hattı yok. Kart düzeyindeki `playback-only` 6.18'de etkisiz: ayrıştırıcı bu ayarı kart, işlemci ve codec düğümünden sırayla okuyor ve her okuma öncekinin üstüne yazıyor (7.x'te düzeltilmiş) | `playback-only` işlemci ve codec düğümlerine de eklendi; kartta hata kalmadı |

Üçünün de çözümü `board/dts/k3-am67a-t3-gem-o1-display.dtsi` ve `scripts/03-rootfs-image.sh`'de;
ses düzeltmeleri Debian çekirdeğinin DTB'sine de geçti.

Kalan: dmesg'de "HDMI: Unknown ELD version 0" sık yazıyor. Denemedeki monitör HDMI üzerinden ses
desteği bildirmiyor (hoparlörsüz); hata değil. Sesin kulakla doğru duyulduğu hoparlörlü bir ekranda
henüz denenmedi (`speaker-test -c 2 -t sine -f 440 -l 1`).

---

## 28. İkinci yayın: 7.3.5 çekirdekli imajlar (`stable`, `stable-hdmi`)

### 28.1 Neden?

Ana yayın (2026.11) uzun destekli 6.18 LTS'te. Daha yeni çekirdeği isteyenler için aynı sistemin
kernel.org'un güncel kararlı sürümü **7.3.5** ile ikinci bir yayını yapıldı: `release/2026.11-7.3/`.
7.3 LTS değil; 7.4 çıktıktan birkaç hafta sonra kapanır (§24'teki "Neden 6.18 LTS?").

### 28.2 Nasıl yapıldı (22 Kasım)

- `versions.env`'e `STABLE_VERSION=7.3.5`, `STABLE_SHA256`, `STABLE_PKGVER` eklendi.
- `kernels/mainline/build.sh` genelleştirildi: `TRACK=lts|stable` sürümü ve klasörü, `VARIANT=plain|hdmi`
  yamaları ve kart tanımını seçiyor. `kernels/stable/build.sh` ve `kernels/stable-hdmi/build.sh` yalnızca
  bu ikisini ayarlayan tek satırlık betikler. 6.18 çekirdekleri bu değişiklikten etkilenmedi (aynı
  klasörler ve damga dosyaları, yeniden derleme olmadı).
- HDMI serisi 7.3.5'e taşındı: 21 yama (`kernels/stable-hdmi/patches/README.md`, `docs/HDMI-YAMALARI.md`
  §6). Yalnız 0014 uyarlandı; BeagleY-AI kart tarifi (Debian 0021) atlandı.
- Kart tanımları 6.18'dekilerle aynı dosyalar (`-headless.dts`, `-lts-hdmi.dts`); ayar da aynı.
- `build.sh`, `03`, `05` `stable` ve `stable-hdmi` adlarını tanıyor; `06` yayın sürümüne özel not
  (`docs/SURUM-NOTLARI-<sürüm>.md`) varsa onu kullanıyor.

### 28.3 Sonuç

| | Ekransız (`stable`) | Masaüstü (`stable-hdmi`) |
|---|---|---|
| Sürüm | `7.3.5-gemstone-stable` | `7.3.5-gemstone-stable-hdmi+` |
| `Image` / paketteki `.ko` | 27 MB / 852 | 27 MB / 961 |
| DTB | 97 KB | 100 KB |
| İmaj | `…-minimal-20261122-own-kstable.img.xz`, 180 MB | `…-lite-20261122-own-kstable-hdmi.img.xz`, 426 MB |
| Denetlendi | BOOT'ta 7.3.5 çekirdeği ve initramfs | BOOT'taki `Image` ve DTB çekirdek çıktısıyla aynı, `ARMd` imzası; pakette `tidss`, `sii902x`, `display-connector`, McASP, `hdmi-codec`, `powervr`; DTB'de ekran birimi, HDMI köprüsü, ses kartı, GPU, `rgmii-rxid`, ses saati |
| Kartta | henüz denenmedi | henüz denenmedi |

Derleme notu: 4 GB / 4 vCPU ile çekirdekler 40 ve 52 dk (önbelleksiz ilk derleme), iki imaj ~20 dk
sürdü. Sanal makinede donanım sanallaştırması kapalıyken çok vCPU verimsiz olabilir (§12 #5); öneri
değişmedi: 4 vCPU (README "Gerekenler", PROSEDUR §8).

6.18'li ana yayın (`release/2026.11/`) bu derlemeden etkilenmedi; özetleri yeniden denetlendi.
