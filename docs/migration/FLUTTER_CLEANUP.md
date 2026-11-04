# Flutter → React Native / Expo son temizlik

4 Kasım 2026 · Branch: `chore/remove-flutter` · İncelenen başlangıç: `8a60bfe` ve ebeveyni `62946ff`.

## Etkin mimari ve korunanlar

Etkin istemci `mobile-rn/` içindeki React Native/Expo uygulamasıdır. Spring Boot API sözleşmeleri, kimlik/yetki ve ödeme kuralları değişmedi. Hasar analizi FastAPI üzerinden iki fotoğrafın tek Gemini görsel çağrısında değerlendirilmesidir. Yerel hasar dedektörü, YOLO/CarDD/Roboflow eğitim veya inference yolu eklenmedi.

AI Asistan'ın yerel `intfloat/multilingual-e5-small` embedding modeli (384 boyut), SentenceTransformers/PyTorch, pgvector RAG, routing ve ingestion kodu korundu. RAG'e kullanıcı araç/hasar verisi eklenmedi; çalışan bilgi tabanına ingestion yapılmadı.

FCM'nin önceki Flutter kurulumundan kalan token'ı emekliye ayırması, native kuyruk ve hesap/generation korumaları; onboarding kurulum işareti; Inter/Roboto, Material Icons ve font/ikon lisansları korundu. RN asset'leri `mobile-rn/assets/` içinde bağımsızdır. `FlutterMaterialIcons` font-family adı ve tarihsel veri kaynak yorumları kaynak klasöre erişim değildir.

`mobile/` silinmedi veya değiştirilmedi. İmzalama anahtarları, production gizli dosyaları, backend uygulama kodu ve ödeme uygulaması değiştirilmedi. İlk doğrulama aşamasında commit/push yapılmadı. Sonraki kullanıcı talebi bu değişikliklerin kapsamlarına göre ayrı commitlerle `chore/remove-flutter` branch'ine push edilmesini kapsar. Merge/deploy yapılmadı.

## Temizlenen bağımlılıklar

- `audit_dependencies.py` yalnız Java runtime ve Python pinlerini, varsa resolved Python envanterini OSV ile sorgular. `pubspec.lock` okunmaz. Advisory ve sorgu hataları mevcut `--fail-on-findings` kapısını başarısız yapar.
- Security workflow RN `package.json`/`package-lock.json`, Node sürümü ve audit script değişikliklerinde de tetiklenir. Ayrı npm işi lockfile'ın runtime ve development bağımlılıklarını mevcut `audit:ci` politikasıyla denetler. Registry hatası temiz rapor sayılmaz; dar CLI istisnasının son tarihi **30 Kasım 2026 00:00 UTC** olarak korunur.
- Memory workflow Flutter feature yolları yerine RN assistant/profile/billing yollarını izler. AI derleme/regresyon ve backend Maven test işleri korundu.
- Üç Flutter görsel harness'i ve `scripts/save-references.mjs` kaldırıldı; önceki commit'te kaldırılan `audit:flutter`, inventory ve asset import araçları geri eklenmedi. Eski araçların kaynağı Git geçmişindedir.
- `visual/native-capture.mjs rn` ve `native-matrix.mjs` yalnız RN `.dev` uygulamasını açar. `rn --standalone` paketlenmiş fixture-only `.dev` APK için Metro gerektirmeyen başlatmayı destekler. `visual:android:smoke`, loopback fixture ve kayıtlı PNG karşılaştırması korunur. CI'ya fixture sunucusu ve PNG boyut/fark kapılarının regresyonları eklendi. Fixture sunucusu varsayılan loopback 18080'i korur; CI testleri `UI_FIXTURE_PORT=0` ile ayrı geçici port kullanır.
- AI'nin 48 MP reddetme fixture'ı byte değişmeden `ai-service/tests/fixtures/48mp.jpg` altına alındı. Normal AI testleri Flutter ağacını okumaz. İsteğe bağlı native çift testi `MOBILE_IMAGE_CONTRACT_DIR` altındaki `detail.jpg` ve `overview.jpg` dosyalarını kullanır.

## Doğrulama

| Kontrol | 4 Kasım sonucu |
| --- | --- |
| TypeScript / ESLint | Geçti |
| Jest | 20 suite, 125 test geçti; FCM geçişi, oturum/alan, asistan ve font/PDF regresyonları dahil |
| CI scriptleri | 20/20 geçti; Java DEX/R8, release fail-closed, OTA, güvenlik politikası, fixture/PNG kontrolleri |
| OSV envanter/hata regresyonları | 5/5 geçti; `mobile/` bulunmayan geçici kökte Maven/PyPI kapsamı doğrulandı |
| Python compileall / AI testleri | Geçti; 69 testten 68'i geçti, native çıktı dizini verilmediği için 1 isteğe bağlı sözleşme testi atlandı |
| Workflow YAML / korunan kaynaklar | Tüm YAML dosyaları ayrıştırıldı; backend/AI job tanımları başlangıçla aynı. Mobil asset/FCM, backend API/ödeme ve AI RAG kaynaklarında tracked diff yok |
| Expo development config / SDK uyumu | Geçti; SDK kontrolü CI ile aynı offline bundled sürümlerine göre yapıldı |
| Genel RN format kontrolü | Başlangıçtan değişmemiş `app.config.ts`, `config/otaUpdate.cjs`, `config/otaUpdate.d.cts`, `scripts/ota-config.test.mjs` uyarıları nedeniyle başarısız; değiştirilen RN dosyaları formatlandı |
| RN standalone smoke | Geçti: ana ekran, araçlar, analiz geçmişi, profil, rehber ve rapor; 6/6 PNG doğrulandı. `node visual/native-capture.mjs rn --standalone`; Flutter/Metro kullanılmadı |
| Tam native UI smoke | **Başarısız**: doğrulanmış mevcut fixture-only `.dev` APK ile 8 ekran/tema/yazı ölçeği matrisi, giriş/klavye ve araç listesi/aksiyon kontrolleri geçti; araç formunda `Marka seçin` zaman aşımı. Bu koşu yeni native build değildir; fixture APK hash'i aşağıdadır |
| Maven runtime envanteri | `dependency:list` başarılı |
| OSV canlı sorgu | 222 paket: 210 Maven, 12 PyPI; 0 sorgu hatası. 3 pakette advisory; kapı beklenen şekilde **başarısız** |
| npm lockfile audit kapısı | Geçti; 45 bulgu: 2 high / 42 moderate / 1 low. High bulgular `@expo/cli` ve `zod` için mevcut süreli istisna kapsamında; yeni istisna eklenmedi |

OSV bulguları `guava@33.1.0-jre` (`GHSA-xxph-c9ww-hj94`), `opentelemetry-api@1.62.0` (`GHSA-ccrj-gw8r-854m`) ve `pypdf@6.19.0` (18 advisory) üzerindedir. Güvenlik kapısı devre dışı bırakılmadı; mevcut Java/Python sürümleri bu mobil temizlik kapsamında değiştirilmedi. Tam raporlar ignored `target/security-dependency-audit.json` ve `mobile-rn/coverage/npm-audit.json` içindedir. Önceki belgelerdeki 18 npm bulgusu tarihsel sonuçtur.

Yerel koşular Node 26.13.0, JDK 21 ve Python 3.13.14 ile yapıldı; CI Node sürümünü `.nvmrc` (24.21.0), Python sürümünü workflow (3.12) üzerinden seçmeye devam eder.

Cihaz koşusu API 36/x86_64 salt okunur emülatörde, yalnız sentetik loopback fixture ile yapıldı. Kullanılan mevcut fixture-only APK SHA-256: `fda5077b714454b74fbe25dd5ceec5e68fad7ba82c62714029b1da5c45a3197e`; metadata hash'iyle eşleşti. İlk native koşu input ANR, ikinci tam matris `Marka seçin` timeout ile durdu. Tam matris başarılı sayılmadı; uygulama/UI kodu bu temizlik kapsamında değiştirilmedi. Tam matris sonucu `target/flutter-cleanup-native/ui-smoke-results.json`; başarılı 6 ekran standalone koşusu `target/flutter-cleanup-native/standalone-smoke.log` ve `mobile-rn/visual-artifacts/flutter-cleanup/standalone/` içindedir. Önceki ignored test kanıtı işlem sonunda geri yüklendi.

Sandbox ilk koşuda alt süreç/geçici dizin/ağ erişimini engelledi; CI scriptleri, Python testleri ve canlı auditler yerel izinli tekrar koşularıyla değerlendirildi. Mock Gemini testleri ücretli çağrı yapmaz.

## `mobile/` kaldırılırken kalan bağımlılıklar

- Etkin tracked CI/build/test kodunda `mobile/` dosyası okuyan zorunlu yol kalmadı. `mobile/` klasörü bu çalışmada fiziksel olarak taşınmadı/silinmedi; bu sonuç kaynak taraması ve bağımsız audit/fixture testlerine dayanır.
- **Ignored yerel production ayarları doğrulanmadı/değiştirilmedi.** `ANDROID_KEYSTORE_PROPERTIES_FILE`, `ANDROID_KEYSTORE_BASE_DIR`, `GOOGLE_SERVICES_FILE` ve dış dosya yolları operatör tarafından klasör silinmeden önce kontrol edilmelidir. Şablonlar RN `secrets/` yollarını gösterir; eski bir ignored override hâlâ `../mobile/...` gösteriyorsa release kırılabilir. Anahtar veya secret taşınmadı.
- `docs/migration/flutter-inventory.json`, `reference/manifest.json`, kayıtlı PNG/JSON'lar ve tarihli billing/cost/ui/security raporları eski Flutter kaynak yollarını ve test komutlarını tarihsel kanıt olarak içerir. Klasör silinirse bu eski kaynak bağlantıları ve Flutter önizleme yeniden üretimi çalışmaz; RN smoke ve kayıtlı PNG karşılaştırması bağımsızdır.
- `.gitignore`/`.dockerignore` içindeki eski Flutter ignore girdileri dosya varlığı gerektirmez.
- Korunan FCM geçiş mantığı, eski uygulama kimliği/sürüm/ABI karşılaştırmaları ve `FlutterMaterialIcons` font adı kaldırılacak bağımlılık değildir; mevcut kullanıcı uyumluluğunu korur.
- `docs/security/dependency-audit-summary.json` 21 Ekim tarihli tarihsel taramadır; güncel güvenlik sonucunun yerine kullanılmaz.

Yeni yayın, native build/cihaz kabulü ve production servis doğrulaması için [RN README](../../mobile-rn/README.md), [Android release](../production/ANDROID_RELEASE.md) ve [görsel kayıt](VISUAL_PARITY.md) esas alınır.
