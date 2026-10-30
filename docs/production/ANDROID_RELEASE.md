# Android production release hazırlığı — 30 Ekim 2026

Başlangıç `master` / `4e21fc1`; branch `release/react-native-production`. Hedef, Flutter uygulamasının **aynı Play kaydına güncelleme**: `com.gorkem.ekspersiz`, ad `EksperSiz`, versionName `1.0.1`, versionCode `53`. Kullanıcı tüm Play track/taslakları için en yüksek kodu `52` olarak ve Play App Signing SHA-1/SHA-256 değerlerini doğruladı. Sonraki yayınlarda maksimum kod yeniden kontrol edilir.

**Karar: production rollout için NO-GO.** Yerel derleme ve konfigürasyon doğrulaması mağaza/cihaz kabulünün yerine geçmez. Aşağıdaki açık kapılar kapatılmadan yayın kararı verilmez. Bu çalışma konsol/production veri değişikliği, gerçek ödeme, ücretli Gemini isteği veya Play yüklemesi yapmaz. iOS release bu kapsamda değildir.

## Kimlik, servisler ve mevcut kullanıcılar

| Alan                   | Doğrulama / davranış                                                                                                                                                                                                                                                                                                                                                                 |
| ---------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Paket/namespace        | Development `com.gorkem.ekspersiz.dev`; production Flutter ile aynı `com.gorkem.ekspersiz`. Development URL şemaları production manifestine taşınmaz.                                                                                                                                                                                                                                |
| Sürüm ve cihaz kapsamı | Kod 53 > doğrulanan 52. Flutter AAB'deki `armeabi-v7a`, `arm64-v8a`, `x86_64` korunur. Expo minSdk 24, compile SDK 37, target SDK 36; JDK 21, NDK 27.1.12297006, CMake 3.31.6 ve build-tools 37.0.0 korunur. Play device catalog karşılaştırması ayrıca gerekir.                                                                                                                     |
| İmza                   | `mobile/android/key.properties` ve onun işaret ettiği mevcut private upload key kullanılır. Store/key parolaları Java Properties ile okunur; argv, log, Expo extra veya generated Gradle'a yazılmaz. Mevcut anahtar sertifikası yerel eski Flutter AAB imzalayan sertifikayla eşleşti. Yeni upload key üretilmez.                                                                    |
| API                    | Flutter `API_BASE_URL` ile RN public API değeri eşleşti. Production yalnızca `https://ekspersiz-backend-production.up.railway.app/api/v1` kabul eder. Eksik/yanlış production URL runtime'da da development adresine düşmez.                                                                                                                                                         |
| Google                 | Flutter server/web Client ID ve RN değeri eşleşti; yerel backend `GOOGLE_AUTH_CLIENT_ID` de eşleşti. Bu, canlı Railway ayarının doğrulandığı anlamına gelmez. Firebase production JSON içindeki type 3 web client ve production package + kullanıcıdan alınan Play SHA-1 içeren type 1 Android OAuth kaydı doğrulanır. Backend `/auth/google` ID token audience doğrulaması korunur. |
| Firebase               | Mevcut Flutter production Android client JSON yeniden kullanılır; yeni proje/app veya admin key eklenmez. İlgili dosya `GOOGLE_SERVICES_FILE` ile native build'e verilir. `.dev` için bu production dosyası kullanılamaz.                                                                                                                                                            |
| Maps / Places          | Flutter `mobile/android/local.properties` içindeki **Android Maps SDK** key'i Android public değişkenine aktarılır. Backend Places server key'i uygulamaya taşınmaz. Mevcut package/Play sertifikası kısıtları Console'da doğrulanmalı.                                                                                                                                              |
| RevenueCat             | Flutter ve RN Android `goog_` public SDK key'i eşleşti. Server `billingCustomerId`, mevcut offering/katalog/SKU ve server sync/ledger kullanılır. Backend doğrulaması olmadan kredi veya Business erişimi verilmez.                                                                                                                                                                  |
| JWT / yerel tercihler  | Flutter Secure Storage ile Expo SecureStore formatı aynı değildir; şifreli token kopyalanmaz. Mevcut kullanıcı bir kez yeniden giriş yapar. Aynı backend hesabının kredi, araç, analiz ve şirket kayıtları sunucudan yüklenir. Flutter'ın şifreli workspace/tema tercihleri RN'ye otomatik taşınmaz; sunucudaki üyelik/yetki kuralları uygulanır.                                    |
| Onboarding             | İki native uygulama da `noBackupFilesDir/installation/onboarding_completed` ve `completed` değerini kullanır. Aynı uygulamaya güncellemede tamamlanmış işaret korunur. Eski sürümde işaret yoksa rehber yeniden görünebilir.                                                                                                                                                         |
| FCM geçişi             | Auto-init native varsayılanı kapalıdır. Expo credential bulunmayan ilk açılışta miras kalan Flutter token'ı kapatılır/silinir; aynı işlem native kuyrukta yeni hesap kaydından önce tamamlanır. Mevcut RN token'ı olan oturum her açılışta döndürülmez. Geç credential yanıtı yeni hesabın token'ını silemez.                                                                        |
| Native özellikler      | Gerçek Android ID + Standard Integrity, immediate update, kamera/galeri/mikrofon/konum, özel dosya/PDF cache akışları korunur. Renkler, ekran yerleşimleri ve görsel tasarım değiştirilmez.                                                                                                                                                                                          |

## Fail-closed build ve environment

`.env.local` development içindir. Release script'i yalnızca açıkça verilen `.env.production.local` dosyasını okur, shell'den gelen public/build girdilerini temizler ve `EXPO_NO_DOTENV=1` ile otomatik dotenv yüklemeyi kapatır. Yerel production dosyası, mevcut Flutter client girdileri ve kullanıcıdan alınan Play metadata ile hazırlandı; git dışında kalır.

Şablonlar: `mobile-rn/.env.example` ve `mobile-rn/.env.production.example`. Gerçek değerler raporlara veya PR'a kopyalanmaz.

| Değişken                                                   | Kaynak / koşul                                                                                                                                        |
| ---------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------- |
| `APP_VARIANT`                                              | Açıkça `production`                                                                                                                                   |
| `EXPO_PUBLIC_API_BASE_URL`                                 | Flutter `API_BASE_URL`; mevcut HTTPS `/api/v1`                                                                                                        |
| `EXPO_PUBLIC_GOOGLE_WEB_CLIENT_ID`                         | Flutter `GOOGLE_SERVER_CLIENT_ID`; Firebase type 3, backend audience ile aynı                                                                         |
| `EXPO_PUBLIC_REVENUECAT_ANDROID_PUBLIC_KEY`                | Flutter `REVENUECAT_ANDROID_PUBLIC_KEY`; gerçek Android `goog_` public SDK key. `test_`/secret reddedilir.                                            |
| `EXPO_PUBLIC_GOOGLE_MAPS_ANDROID_API_KEY`                  | Flutter Android `MAPS_API_KEY`; package/sertifika/API kısıtlı client key                                                                              |
| `GOOGLE_SERVICES_FILE`                                     | Mevcut production Android client JSON yolu                                                                                                            |
| `ANDROID_VERSION_NAME`, `ANDROID_VERSION_CODE`             | Bu aday: `1.0.1`, `53`                                                                                                                                |
| `ANDROID_PLAY_MAX_VERSION_CODE`                            | Tüm track/taslaklarda teyit edilen son kod; bu çalışma için `52`                                                                                      |
| `ANDROID_PLAY_SIGNING_SHA1`, `ANDROID_PLAY_SIGNING_SHA256` | **Play App Signing** sertifikası. SHA-1 production Android OAuth kaydıyla karşılaştırılır; SHA-256 backend Integrity kontrolünde ayrıca teyit edilir. |
| `ANDROID_KEYSTORE_PROPERTIES_FILE`                         | Mevcut Flutter `../mobile/android/key.properties`                                                                                                     |
| `ANDROID_KEYSTORE_BASE_DIR`                                | Flutter `storeFile` göreli yolunun tabanı `../mobile/android/app`                                                                                     |

Gemini/RAG/AI service key, JWT secret, Brevo, RevenueCat secret, Places server key, Firebase admin/service-account JSON bu dosyada veya `EXPO_PUBLIC_*` içinde bulunmaz. Release dosyasında tanımsız değişken ve public değişken reddedilir. Dosya yolları dışında signing parolası/anahtarı Expo config'e girmez.

Production native release **debug signing'e düşmez**. Private key/alias/store password/key password gerçek keystore ile doğrulanır. Native kaynak production üretildiyse ham Gradle komutu da explicit release ortamı ister ve debug APK'yı engeller. Hermes zorunlu, dev launcher/menu release kapalı, network inspector kapalı, `debuggable=false`, R8/resource shrink açık, cleartext ve uygulama backup kapalıdır. `android/` generated ve ignored kalır; değişiklikler kalıcı config plugin'indedir.

## Mevcut upload key ile AAB

Node 24.21.0, JDK 21 ve mevcut Android SDK'yı PATH/JAVA_HOME/ANDROID_HOME ile seçin. Windows örneği:

```powershell
cd mobile-rn
$env:JAVA_HOME = 'C:\Program Files\Android\Android Studio\jbr'
$env:ANDROID_HOME = "$env:LOCALAPPDATA\Android\Sdk"
npm ci
npm run typecheck
npm run lint
npm test -- --ci
npm run test:ci-scripts
npx expo install --check
npm run check:config
npm run audit:ci
npm run release:check
npm run release:android
```

Başka bir ignored dosya için `npm run release:android -- .env.production.local`. Alt akış `expo prebuild --platform android --no-install` ardından `:app:bundleRelease :app:lintRelease -PreactNativeArchitectures=armeabi-v7a,arm64-v8a,x86_64 --max-workers=2 --no-daemon` çalıştırır. Ham Gradle kullanmak yerine bu komutu kullanın; development shell/env veya Expo template debug key'ine güvenmeyin.

Yalnızca başarılı lint/merged manifest, Hermes bytecode, 64-bit ELF 16 KiB hizalaması ve AAB'nin tüm dosyalarında mevcut upload sertifikasıyla JAR imzası doğrulandıktan sonra çıktılar `mobile-rn/release-artifacts/` içine kopyalanır:

- `ekspersiz-1.0.1-53.aab`
- `ekspersiz-1.0.1-53-mapping.txt`
- `ekspersiz-1.0.1-53-verification.json` (AAB hash'i, public sertifika metadata, ABI kontrolleri)

Bu klasör git dışındadır. Eksik anahtar/servis girdisinde script açık hata verir; yeni anahtar üretmez veya test değerleriyle production artifact oluşturmaz. Build çıktısının oluşması, Play App Signing, canlı servis veya cihaz kabulünün tamamlandığı anlamına gelmez.

Bu çalışma sırasında gerçek yerel girdiler ve mevcut upload key ile yukarıdaki AAB üretildi: **65.35 MiB**, SHA-256 `289b812d8649b038d5138dd8d548f99a9f16cb571d7fd18ec8db00f7b8d8d78b`. 1,248 AAB dosyasının imzası ve 87 native kütüphane kontrol edildi; üç ABI ve Hermes doğrulandı. İmza, upload certificate ile doğrulanır; Play dağıtımındaki APK'yı Google App Signing sertifikasıyla yeniden imzalar.

## Google Login: development DEVELOPER_ERROR

Statik bulgu: web/server client doğru ve Flutter ile aynı; production Firebase JSON yalnızca `com.gorkem.ekspersiz` içeriyor. RN `.dev` app farklı Android OAuth kimliğidir. Hatanın cihaz/Console seviyesinde kesin kaydı bu ortamda görülmedi; çalışan Flutter web client'ını rastgele değiştirmek çözüm değildir. Google Sign-In SDK'sı bu hatayı yapılandırma eşleşmezliği olarak tanımlar. [Resmî troubleshooting](https://react-native-google-signin.github.io/docs/troubleshooting).

Google Cloud Credentials / Firebase Project settings üzerinde şu Android OAuth kayıtlarını doğrulayın:

| Dağıtım                                     | Android package            | Gerekli SHA-1                                                                        |
| ------------------------------------------- | -------------------------- | ------------------------------------------------------------------------------------ |
| RN development APK                          | `com.gorkem.ekspersiz.dev` | RN `android/app/debug.keystore` sertifikası                                          |
| Yerel imzalı production APK ile giriş testi | `com.gorkem.ekspersiz`     | Mevcut **upload key** sertifikası                                                    |
| Play'den kurulan production güncellemesi    | `com.gorkem.ekspersiz`     | **Play App Signing** sertifikası; kullanıcıdan alınan SHA-1 Firebase JSON'da bulundu |

Development public parmak izi komutu: `keytool -list -v -keystore android/app/debug.keystore -alias androiddebugkey -storepass android`. Production upload certificate için parolayı komut satırına yazmayın; ignored verification JSON'daki public fingerprint'i kullanın / Android Studio Signing Report'u ortamdan çalıştırın. Aynı Cloud projesinin **Web application** client ID'si RN public ayarında ve backend `GOOGLE_AUTH_CLIENT_ID` içinde kalmalı. Android client ID, webClientId yerine kullanılmaz. `.dev` FCM de isteniyorsa ayrı `.dev` Firebase Android client kaydı ve ona ait JSON gerekir; production JSON `.dev` paketine verilmez. Native yapılandırma değişikliğinden sonra yeniden prebuild/build gerekir.

## Kullanıcının tamamlayacağı konsol/cihaz kabulü

| Öncelik | Kontrol                                   | Kabul kanıtı                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         |
| ------- | ----------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| P0      | **Gerçek Flutter 52 → RN 53 yükseltmesi** | Play Internal Testing ile mevcut Flutter kurulumu üzerine, uninstall/data clear olmadan güncelle. Aynı applicationId/Play sertifikası; tek yeniden giriş sonrası aynı kullanıcı ID, kişisel kredi bakiyesi, araç/analiz geçmişi, Business üyelik ve şirket bakiyesi. Workspace izolasyonu ve onboarding işaretini doğrula.                                                                                                                                                                                                                                                           |
| P0      | **Ödeme ve ledger uzlaştırması**          | Mevcut RevenueCat app/offering/entitlement/SKU'ları ve Play ürün durumlarını salt okunur doğrula. License tester/test ödeme yöntemiyle pending → tamamlanma, cancel, restore, upgrade/downgrade, refund/revoke, gecikmiş/tekrar webhook. Aynı transaction yalnızca bir ledger etkisi; şirket sahibi/üye/sona eren üyelikte doğru wallet. Test verisi için izole staging/test hesapları; gerçek ödeme yapılmaz.                                                                                                                                                                       |
| P0      | **Integrity ve başlangıç kredisi**        | Play API bağlantısındaki Cloud project, backend `PLAY_INTEGRITY_PACKAGE`, `PLAY_INTEGRITY_CERTIFICATE_SHA256`, `PLAY_INTEGRITY_CLOUD_PROJECT_NUMBER` ve credential erişimi doğru mu kontrol et. Package `com.gorkem.ekspersiz`. Backend mevcut karşılaştırmada decoded `certificateSha256Digest` ile **base64url SHA-256** bekler; Console'daki `AA:BB...` hex doğrudan bu değere yazılmaz. Mevcut doğru Flutter ayarı korunmalı. Play'den kurulu gerçek cihazda server challenge requestHash, `PLAY_RECOGNIZED`, `LICENSED`, device integrity ve tekrar kredi alamama doğrulanmalı. |
| P1      | **Google release girişi**                 | Play imzalı uygulamada web audience/server doğrulaması, Google hesap değiştirme, consent cancel, logout, expired/401 ve e-posta girişi. Yerel config eşleşmesi canlı Railway/Console kanıtı değildir.                                                                                                                                                                                                                                                                                                                                                                                |
| P1      | **FCM**                                   | Aynı Firebase project/app; Android 13+ izin accept/deny, foreground/background/terminated tap ve doğru bildirim listesi. Flutter'dan upgrade sonrasında eski token iptali, refresh, A→logout→B, offline logout ve geç native cevapta B'nin token'ının korunması. İki servis offline iken anlık uzaktan iptal/OS'ta önceden kuyruğa alınmış bildirimin geri çekilmesi garanti edilemez. Backend eski/invalid token temizliği gözlenmeli. [FCM token yönetimi](https://firebase.google.com/docs/cloud-messaging/manage-tokens).                                                        |
| P1      | **Play in-app update**                    | `/app/version` mevcut minimum politika ve gerçek Play immediate update/resume. Sideload APK aynı kanıt değildir; minimum sürümü kullanıcı geçişini kilitleyecek şekilde erkenden artırmayın.                                                                                                                                                                                                                                                                                                                                                                                         |
| P1      | **Maps / fotoğraf / PDF / STT**           | Package + Play SHA-1 + Maps SDK API kısıtları; konum deny/timeout. 48/64 MP, farklı EXIF yönleri, HEIC/bozuk/büyük dosya, iptal/geri/logout ve bellek baskısı. Türkçe PDF/çok sayfa/özel paylaşım ve dosya temizliği; Türkçe konuşma sağlayıcısı. Paid analysis bu çalışma sırasında tetiklenmez.                                                                                                                                                                                                                                                                                    |
| P1      | **Release performansı / cihaz kapsamı**   | Fiziksel ARM64, düşük RAM/API 24 ve 16 KiB cihaz; cold/warm start, tab geçişi, resim decode, JS/UI frame, peak RSS/PSS, uzun kullanım. Debug emülatör sonucu release performansı sayılmaz. Play device catalog ve pre-launch report karşılaştırılmalı. ELF hizalaması tek başına 16 KiB cihaz çalışma testi değildir. [Android rehberi](https://developer.android.com/guide/practices/page-sizes).                                                                                                                                                                                   |
| P1      | **Bağımlılık güvenliği**                  | npm audit: CLI zincirindeki 3 high / 15 low için mevcut dar istisna 2026-11-30 UTC'de biter. Zod/deepmerge runtime sourcemap kapısı korunur; force/uyumsuz upgrade uygulanmadı. İzole ledger/idempotency/concurrency ve security DB regresyonları aşağıdaki yerel/CI koşularında tamamlandı.                                                                                                                                                                                                                                                                                         |

RevenueCat restore tüketilmiş consumable kredinin yerel olarak yeniden verilmesi değildir; bakiye ledger'dan gelir. `/billing/sync` mevcut provider purchase listesiyle idempotent server uzlaştırması yapar. Flutter'ın JWT/tercihleri kopyalanmadığı için eski ödeme state'i varmış gibi bir yerel entitlement uydurulmaz. Store'da sonucu belirsiz işlemle yükseltme senaryosu özellikle test edilmelidir. [RevenueCat restore davranışı](https://www.revenuecat.com/docs/getting-started/restoring-purchases).

## Performans ve test kapsamı

Tek davranışsal performans düzeltmesi: boot'taki backend minimum-version GET'i ve Play update kontrolü artık bağımsız/paralel; ikisi de yanıt vermezse iki ardışık 5 saniye yerine ortak yaklaşık 5 saniyelik kontrol bütçesi kullanır. Jest fake-timer testi bu davranışı doğrular; gerçek release startup süresi iddiası değildir. React Query 30 saniye cache, pencere odağında refetch kapalı, korumalı generation key'leri, lazy native auth/store başlatma, bounded native image/PDF cache ve Reanimated native akışı korundu. Ölçüm olmadan render/memoization refactoring'i yapılmadı.

Yerel kontrollerin sonuçları ve CI linkleri PR'da güncellenir. CI `checks` TypeScript/ESLint/Jest/script/Expo config-dependency/audit + Android/iOS JS export/runtime sourcemap kontrolünü korur. Mevcut `android` job adı/debug APK + lint + merged manifest kontrolü korunur; `android-release` aynı SDK ile **production kimliği/girdisi kullanmadan `.dev` release smoke** bundle, R8, resource shrink, release lint, Hermes/signature/64-bit ELF 16 KiB kontrollerini ekler. Production upload key veya servis credential'ı CI'ya eklenmez.

`48efe69` uygulama kodu için [RN readiness CI](https://github.com/GorkemErtas/ekspersiz/actions/runs/41102512422) üç işi de başarıyla tamamladı: `checks`, `android` (29m43s native build) ve `android-release` (31m04s native build). Release smoke'ta 1,221 task sıfırdan çalıştı; manifest, Hermes, imza ve 64-bit ELF hizalaması geçti. [PostgreSQL 16/pgvector kredi CI](https://github.com/GorkemErtas/ekspersiz/actions/runs/41104199941) 371 testte sıfır hata/atlama ile tamamlandı. Sonraki lisans/dokümantasyon commit'leri uygulama kodunu değiştirmez; bu commit'ler için otomatik CI tekrarının güncel durumu PR'da belirtilir.

| Yerel doğrulama                                        | Sonuç                                                                                             |
| ------------------------------------------------------ | ------------------------------------------------------------------------------------------------- |
| TypeScript / ESLint                                    | Geçti                                                                                             |
| Jest / CI script regresyonları                         | 118 / 11 geçti                                                                                    |
| Expo bağımlılık / config / gerçek production preflight | Geçti                                                                                             |
| Production `bundleRelease` + `lintRelease`             | 23m 46s; 1,246 task, başarılı. Lint 0 hata / 38 uyarı; lint kapatılmadı.                          |
| Production merged manifest                             | Tam paket/kod, izinler, cleartext/backup/debug kapalı, FCM/Maps ve FCM auto-init politikası geçti |
| Gerçek release runtime sourcemap                       | 2,162 kaynakta kabul edilen CLI/Zod/deepmerge bulgusu runtime'a taşınmıyor                        |
| Backend Maven ilk offline koşu                         | 315 geçti / 53 atlandı; eksik DB kapsamı aşağıdaki ek koşularla tamamlandı                        |
| Backend JDBC / izole yerel PostgreSQL 18               | 54 geçti / 0 atlandı; yeni test cluster'ları işlem sonunda kapatıldı                              |
| Backend / PostgreSQL 16 + pgvector CI                  | 371 geçti / 0 atlandı; ledger/security, Docker ve Spring/JPA entegrasyonları dahil                |
| Flutter referansı                                      | 296 geçti                                                                                         |
| FastAPI / Flutter image contract                       | 69 geçti; ücretli Gemini çağrısı yapılmadı                                                        |
| npm audit                                              | 3 high / 15 low; mevcut dar ve süreli CLI istisnası dışında bloklanan bulgu yok                   |
| Gerçek cihaz / Play / canlı servis / ödemeler          | Yapılmadı; manuel kabul matrisinde açık                                                           |

## Yayın prosedürü

1. Bu branch'in PR'ını ve CI sonuçlarını inceleyin; bu çalışma master'a merge etmez. Yayından hemen önce Play maksimum versionCode ve iki sertifikayı yeniden teyit edin. Upload certificate ile **App signing certificate** farklı roller taşır. [Android signing](https://developer.android.com/studio/publish/app-signing).
2. Mevcut Play uygulamasının Internal Testing track'ine imzalı AAB'yi **siz** yükleyin. Yeni applicationId/app kaydı açmayın. Release notes, Data safety/izin beyanı, cihaz kapsamı, mapping/native-symbol metadata ve pre-launch raporunu inceleyin.
3. Mağazadan kurulu Flutter 52'yi aynı test kullanıcısıyla RN 53'e güncelleyin. Veri silmeyin/uninstall yapmayın. Yukarıdaki kabul matrisini tamamlayın; yeniden giriş beklenir, backend veri/üyelik/kredi kaybı beklenmez.
4. Açık P0/P1 kapıları ve izole DB testleri tamamlanınca sınırlı staged rollout kararı verin; auth/crash/FCM/ödeme/webhook/ledger metriklerini izleyin. Backend minimum Android build değerini yayılım/kabul tamamlanmadan yükseltmeyin.
5. Sorunda rollout'u durdurun. Daha düşük versionCode ile mağaza rollback'i yapılamaz; korunmuş Flutter kodundan **daha yüksek versionCode** ile forward-fix planlayın. RN session/tercihleri Flutter'a geri taşınmadığından tekrar giriş beklentisini ve veri kabulünü bu senaryoda da test edin. Production DB rollback/migration yapılmaz.
