# Migration doğrulama kaydı

29 Ekim 2026 — `migration/flutter-to-expo`. Yalnızca geliştirme uygulaması; production deploy/master merge yok.

| Kontrol                   | Sonuç                        | Kanıt / sınır                                                                                                                  |
| ------------------------- | ---------------------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| TypeScript                | Geçti                        | strict `tsc --noEmit`                                                                                                          |
| ESLint                    | Geçti                        | `eslint .`; native deferred require istisnaları gerekçeli                                                                      |
| Jest                      | **88 test / 16 suite geçti** | Auth/session/scope, binary streaming ve multipart, tracking, assistant, billing, GPS ve PDF                                    |
| Expo Doctor               | **20/20 geçti**              | Local modül kaynaklarını dışlayan geniş gitignore düzeltildi; kullanılmayan legacy ikon paketi kaldırıldı                      |
| Expo bağımlılık uyumu     | Doctor kontrolü geçti        | Lockfile SDK 58/RN 0.88.1 ile                                                                                                  |
| Android native            | **Geçti**                    | x86_64 debug APK; son derleme 9m43s, 683 task. Kotlin özel modülü, Maps, Firebase, RevenueCat ve STT native paketleri derlendi |
| Android JS/Hermes export  | **Geçti**                    | 8.7 MB `.hbc`; yalnızca yerel export, deploy değil                                                                             |
| iOS JS/Hermes export      | **Geçti**                    | 8.7 MB `.hbc`; Swift/Xcode derlemesi anlamına gelmez                                                                           |
| iOS native                | **Çalıştırılmadı**           | macOS/Xcode, provisioning ve gerçek cihaz gerekir                                                                              |
| Statik secret taraması    | Eşleşme yok                  | 112 source/config/native dosyasında private key ve bilinen secret biçimleri; kapsamlı güvenlik denetiminin yerine geçmez       |
| npm audit                 | **18 bulgu kaldı**           | 15 low, 3 high; Expo CLI → Zod. gRPC 1.13.6 override ile ilgili zincir düzeltildi. Uyum bozan forced major/downgrade yapılmadı |
| Flutter/backend korunması | Diff yok                     | `mobile/`, backend `src/`, `pom.xml`, `ai-service/` üzerinde tracked kaynak değişikliği yok                                    |
| Backend regresyonu        | Çalıştırılmadı               | Backend değiştirilmedi                                                                                                         |
| Üretim performansı        | Ölçülmedi                    | Software emülatör/debug ölçümü release FPS kanıtı olarak sunulmaz                                                              |

## Native cihaz senaryoları

API 36 x86_64 emülatör, 390×844 / density160 / text1.0; uygulama `com.gorkem.ekspersiz.dev`. Backend taşıması açıkça test-only `127.0.0.1:18080`; kullanıcı/araç/görseller sentetiktir. Uygulamanın kendi native kamera/galeri/dosya/PDF/klavye kodu çalışır.

| Senaryo                     | Gözlenen sonuç                                                                                                                                                                 |
| --------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Ana sekmeler, rehber, rapor | Native ekranlar açıldı; Flutter karşılıklarıyla görüntüler kaydedildi                                                                                                          |
| Asistan + klavye            | Gönderme düğmesi klavye üstünde kaldı (`y449–497`); gerçek TextInput’tan soru gönderildi, native Markdown yanıtı render edildi                                                 |
| Konum + iki fotoğraf        | Emülatör GPS fix’i alındı, şehir girildi, gerçek sistem seçicisinden farklı iki 768×512 PNG seçildi, native JPEG hazırlandı                                                    |
| Multipart + analiz          | Sıra: `POST /inspections`, `POST /inspections/2/image`, `POST /inspections/2/context-image`, **tek** `POST /inspections/2/analyze`; sonuç route’u açıldı                       |
| Analiz tekrar güvenliği     | Altı job testi: tamamlanan/processing iş, reentrant start, kayıp yanıt, ilk GET’ten önce biten polling, scope değişimi ve başarısız recovery. Otomatik ikinci ücretli POST yok |
| Tutanak                     | Native formdan DRAFT kaydedildi; native onayla `FINALIZED`; sunucudan 64 karakter SHA-256 ve snapshot alındı                                                                   |
| Tutanak PDF                 | Snapshot/hash kontrolünden sonra Android **Sharing 1 file** penceresi `EksperSiz_Tutanak_EXP-TEST-1.pdf` ile açıldı; harici alıcıya gönderilmedi                               |
| Rapor PDF                   | Android’in gerçek yazdırma önizlemesinde Türkçe metin, görsel ve iki sayfa görüldü; yazdırma işi gönderilmedi                                                                  |

İlgili görseller [native/](native/) içindedir. Bunlar gerçek AI analizi, mağaza tahsilatı, e-posta teslimi veya FCM teslimi yapıldığını göstermez.

Android geri tuşu ayrıca native uygulamada doğrulandı: araç detayı → garaj, ardından garaj → ana sayfa geçti.

## Açık kabul işleri

- Development hesap/anahtarlarıyla gerçek Google/e-posta/AI, RevenueCat sandbox/webhook/ledger, iki Business hesabı, FCM/APNs ve Play Integrity/update testi.
- iOS Swift/native derleme, StoreKit, Maps/STT izinleri ve VoiceOver; fiziksel ARM64 cihaz testi/release profillemesi.
- Tüm ekranların loading/error/empty/offline, font/keyboard, tablet/landscape, reduced-motion ve TalkBack/VoiceOver matrisi; Flutter PDF belge karşılaştırmaları.
- npm audit high/low bulgularının uyumlu upstream sürümlerle giderilmesi.

Görsel fark yüzdeleri ve kabul ayrımı [VISUAL_PARITY.md](VISUAL_PARITY.md) ve [feature-comparison.json](native/feature-comparison.json) içindedir. Sayısal başarısızlıklar saklanmaz; tolerans sonuç elde etmek için yükseltilmez.
