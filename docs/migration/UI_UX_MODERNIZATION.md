# React Native UI/UX modernizasyonu — 31 Ekim 2026

Başlangıç: güncel `master / 62aa131`; branch `feat/react-native-ui-modernization`.

## Uygulama öncesi inceleme

Expo Router korumalı stack'i, MainShell'in ziyaret edilen sekmeleri koruyan yapısı, ThemeProvider, ortak Page/Card/Field/Button/Select/Sheet bileşenleri ve mevcut native fixture altyapısı incelendi. Giriş/kayıt/şifre ekranları, dashboard, araç liste/form/detay/takip, analiz oluşturma/yükleme/sonuç/geçmiş/tutanak, asistan, bildirim, profil, billing ve Business ekranlarının yerleşimleri gözden geçirildi.

| Alan | Somut bulgu | Uygulama yaklaşımı |
| --- | --- | --- |
| AI düğmesi | MainShell kökünde absolute `bottom: 98/128`; daha sonra çizilen ve font/inset ile büyüyen menüden bağımsız | İçerik, AI eylem alanı ve navigasyonu normal yerleşimde ayır; düğme için içerik alanı ayır |
| Dashboard | FAB için 200 px, diğer sekmelerde 120 px sabit boşluk; dar başlıkta avatar + metin + iki aksiyon yarışıyor | Yapısal footer sonrası doğal scroll sınırı; sarılabilen başlık ve aksiyon grubu |
| Formlar | Field etiketi absolute `top: -9 * fontScale / 16`; multiline/değer/etiket büyük yazıda çakışabilir | Etiketi normal akışta tut; ortak input ölçüleri, hata ve disabled durumlarını standartlaştır |
| Araçlar | Yıl elle giriliyor; ekle düğmesi absolute; 208 px koordinat menüsü büyük yazı/rotasyonda taşabilir | Mevcut native Select ile dinamik yıl; akışta CTA; ortak Sheet ile aynı araç aksiyonları |
| Logo | 1254×1254 opak görsel; parlak marka sınırları yaklaşık (91,81)–(1146,1125). Auth `cover` ve yuvarlatma kullanıyor; aynı tam görsel launcher foreground'unda | In-app `contain`; orijinal bitmap'i değiştirmeden adaptive XML inset; bağımsız, sınırlı splash boyutu |
| Ortak yerleşim | Section başlığı/aksiyonu ve toolbar aynı satıra zorlanıyor; Sheet %72 yükseklikte, keyboard/reduced-motion işlemi yok | Esnek satırlar, dinamik toolbar yüksekliği, erişilebilir ve kaydırılabilir Sheet |
| Hareket | Button/icon/card press geri bildirimi birbirinden farklı; mevcut Reanimated ve motion token'ları var | Ortak press primitive, kısa UI-thread geçişleri; reduced motion ile hareketi kaldır |

Launcher için [Android'in foreground ve safe-zone rehberi](https://developer.android.com/develop/ui/compose/system/icon_design_adaptive) esas alınır. Orijinal logo ve marka kimliği korunur; bitmap yeniden çizilmez.

## Uygulanan değişiklikler

- `MainShell`: içerik, asistan eylemi ve navigasyon ayrı normal layout alanlarıdır. FAB için absolute koordinat, zIndex ve sahte içerik boşluğu kullanılmaz. Yatay/geniş ekranda kaydırılabilen yan menü, telefonda büyüyen alt menü kullanılır. Sekmelerin ziyaret edilmiş ekran state'i ve mevcut asistan rotası korunur.
- `components`, `layout`, `Sheet`: kalıcı alan etiketleri, sarılan toolbar/section aksiyonları, erişilebilir touch target'ları, arama destekli sanallaştırılmış seçim listesi ve klavyeye göre ölçülen sheet yüksekliği. Android edge-to-edge altında yalnızca `adjustResize` yeterli olmadığı native görüntüde görüldü; KeyboardAvoidingView ve ölçülen toolbar offset'i kullanılır.
- `VehicleFormScreen`, `vehicleYears`: cihaz takvimine göre güncel yıldan 1950'ye azalan seçenekler; kayıttaki aralık dışı yıl açıkça gösterilir ve değişmeden saklanabilir. Payload hâlâ sayısal `modelYear` gönderir. Araç listesinin ekle eylemi normal akışta, düzenle/sil menüsü ortak Sheet içindedir.
- `TouchSurface`, motion/spacing token'ları, dashboard: ortak kısa Reanimated press/sekme geri bildirimi, reduced-motion desteği, daha sade kartlar ve sarılabilen başlık/aksiyonlar. İşlem loading/disabled kilitleri ve onPress davranışları korunur.
- `AuthShell`, `app.config`, `withAndroidBranding`: orijinal logoyu contain ile sınırlar; splash 112 dp, adaptive icon foreground inset %22. Kalıcı config plugin prebuild sonrasında launcher ve round icon XML'lerini düzeltir. Bitmap değiştirilmez.
- Jest ve native görsel altyapısı: yıl seçimi, numeric payload, legacy kayıt, kilometre validasyonu, sekme state'i ve asistan navigasyonu için regresyon testleri; localhost fixture ile native ekran matrisi. Yeni dependency eklenmez.

## Korunan işlevler

API, oturum, Google Sign-In, Gemini/asistan iş kuralları, kredi ve billing/RevenueCat, tracking, bildirim planlama, PDF üretimi ve modeller değiştirilmez. Production signing/version/env ve R8/Room/WorkManager constructor korumaları korunur. Native config değişikliği yalnızca launcher/splash marka yerleşimi içindir. Yeni bağımlılık veya gerçek ücretli istek eklenmez.

## Doğrulama

Uygulama ve anlamlı etkileşim testlerinden sonra typecheck, lint, Jest, format:check ve release script regresyonları çalıştırılır. Android'de sentetik localhost fixture taşımasıyla dar/standart/geniş/landscape, açık/koyu tema, büyük font, klavye ve iki navigasyon modu test edilir. Gerçek servis, gerçek ödeme veya fiziksel cihaz testi yapılmadıkça bunlar doğrulanmış sayılmaz. Gerçek sonuçlar aşağıya kaydedilir.

### Gerçek sonuçlar

| Kontrol | Sonuç |
| --- | --- |
| `npm run typecheck` | Geçti |
| `npm run lint` | Geçti; sıfır uyarı |
| `npm test` | 20 suite, 125 test geçti |
| `npm run test:ci-scripts` | 14 test geçti; R8/constructor, signing/manifest ve yeni branding regresyonu dahil |
| `npm run check:config` | Geçti |
| `npm run format:check` | Geçti; Windows dosyalarının mevcut satır sonlarını koruyan `endOfLine: auto` kullanıldı |
| Android native build | Expo prebuild ardından `bundleRelease assembleRelease lintRelease`, x86_64, optimize edilmiş development varyantı; başarılı |
| R8/Hermes/manifest | Minify ve shrink açık; generated/effective keep kuralları mevcut; iki InputMerger ve WorkDatabase_Impl public boş constructor'ları APK/AAB DEX'inde mevcut; DEX hash'leri eşit |
| Son APK cold-start | API 36 emülatöründe üç ayrı süreçte RN ekranı açıldı; her süreç en az 10 saniye yaşadı; crash/ANR gözlenmedi |
| Ana native UI koşumu | 36 doğrulanmış PNG; 8 düzen, asistan hit-test/navigation ayrımı, sayısal 2024 ile oluşturma ve legacy 1942 ile düzenleme, rapor/tutanak/takip/paket/bildirim/profil/geçmiş, boş/hata/Business owner/member, reduced motion geçti |
| Son APK klavye regresyonu | Giriş, asistan ve yıl araması geçti; odaklı input alt sınırları sırasıyla 545, 533, 224 px; IME başlangıcı 545 px |
| Son APK dönüş/büyük yazı | Gerçek `rotation=1` ile 844×390; üç tuş/gesture modunda AI hit-test ve Profil navigasyonu geçti. 320×640 / 1.6× yazılı araç formu ve yıl araması geçti; input 222 px'de biterken IME 357 px'de başlıyor |
| Native branding | Launcher çekmecesinde round mask ve cold splash gerçek PNG üzerinden incelendi; test varyantında marka bütünüyle görünür |

Ana düzen matrisi: 320×640 (dark/gesture, light/1.6× yazı/three-button), 390×844 (light/gesture, dark/three-button, dark/2× yazı/gesture), 844×390 (light/three-button), 1024×768 (dark/gesture, light/1.6× yazı/three-button).

Ana UI koşumundan sonra Android'in fazla keyboard offset'i kaldırıldı; etkilenen üç klavye ekranı son APK üzerinde tekrar çalıştırıldı. Son APK/AAB ve cold-start raporu aynı dosya hash'leriyle bağlandı. Fiziksel cihaz doğrulaması yapılmadı.

### Kanıtlar ve test derlemesi

[Native build/R8 raporu](ui-modernization/android-verification.json), [üç cold-start](ui-modernization/cold-start.json), [ana UI koşumu](ui-modernization/ui-smoke-results.json), [son klavye koşumu](ui-modernization/keyboard-smoke-results.json), [gerçek dönüş ve büyük yazılı form](ui-modernization/layout-details-results.json).

| Görsel kontrol | PNG |
| --- | --- |
| Giriş logosu ve klavye | [Logo](ui-modernization/ui-login-logo.png), [klavye](ui-modernization/ui-login-keyboard.png) |
| Dar ekran/açık tema/1.6× yazı | [320×640](ui-modernization/ui-small-light-large-font.png) |
| Standart ekran/koyu tema/2× yazı | [390×844](ui-modernization/ui-standard-dark-font-2.png) |
| Tablet/açık tema/1.6× yazı | [1024×768](ui-modernization/ui-tablet-light-large-font.png) |
| Gerçek 90° dönüş/üç tuşlu navigasyon | [844×390](ui-modernization/ui-rotation-90-three-button.png) |
| Yıl seçimi, legacy yıl ve büyük yazılı arama | [Azalan liste](ui-modernization/ui-vehicle-year-options.png), [1942](ui-modernization/ui-vehicle-legacy-year.png), [320 px/klavye](ui-modernization/ui-small-year-keyboard-font-16.png) |
| Asistan klavye düzeni | [Mesaj alanı](ui-modernization/ui-assistant-keyboard.png) |
| Android launcher/splash | [Round mask](ui-modernization/ui-launcher.png), [splash](ui-modernization/ui-splash.png) |

Launcher görüntüsünde sağdaki **EksperSiz Dev** yeni foreground inset'ini gösterir; soldaki EksperSiz daha önce AVD'ye kurulmuş production sürümüdür. Production paketinin üzerine test APK'sı kurulmadı. Uygulama verileri sentetiktir. Tam PNG/erişilebilirlik dump seti yerelde `mobile-rn/visual-artifacts/ui-modernization/captures` altındadır; seçili 12 PNG burada sürümlenir.

Son dosyalar **production dağıtımı için değildir**: localhost fixture transport, development package/debug signing, x86_64; sürüm 1.0.0 / kod 52. Bu görev production metadata değiştirmez.

- `mobile-rn/visual-artifacts/ui-modernization/app-release.apk` — SHA-256 `fda5077b714454b74fbe25dd5ceec5e68fad7ba82c62714029b1da5c45a3197e`
- `mobile-rn/visual-artifacts/ui-modernization/app-release.aab` — SHA-256 `01d96cb2cc798d6a084d519e374f2613fdf610e6255ec466fb480b2095639ed2`

Ana 36 görüntülük koşum, son keyboard offset değişikliğinden önceki `d6d20ee9a35b5b0e6cc9fbd91c277bf25b6161c950d600d5276145e97c418cb7` APK'sındadır. Yukarıdaki son APK hash'i, tekrar edilen klavye ve gerçek dönüş/büyük yazı raporlarında ayrıca cihazdaki kurulu APK'dan doğrulanır.

### Tekrarlanabilir native kontrol

Özel test AVD'sinde, **development** paketli ve `EXPO_PUBLIC_API_BASE_URL=http://127.0.0.1:18080/api/v1` ile bundle edilmiş APK kullanılır. Fixture üretim uygulamasına import edilmez. Ayrı terminalde `NODE_ENV=development` ile `node visual/fixture-server.mjs` başlatılır. Production environment dosyası yüklenmez (`EXPO_NO_DOTENV=1`); `APP_VARIANT=development`, `ANDROID_RELEASE_OPTIMIZE=1` ile prebuild yapılır; Gradle `:app:bundleRelease :app:assembleRelease :app:lintRelease -PreactNativeArchitectures=x86_64 --max-workers=2 --no-daemon` çalıştırılır. Expo 58 prebuild native dizini yeniden ürettiğinden, yalnız JS değişikliğinde mevcut native dizinden Gradle çalıştırılabilir.

`ANDROID_SERIAL` açıkça seçilmelidir. `UI_CAPTURE_ARTIFACT_DIR` ve `UI_CAPTURE_OUTPUT_DIR` isteğe bağlıdır. İlk koşum, onboarding/girişteki test oturumunu bekler:

```text
npm run visual:android:smoke
npm run visual:android:smoke -- --keyboard-only
npm run visual:android:smoke -- --layout-details
```

`--keyboard-only` girişten başlar; `--layout-details` giriş yapılmış test oturumunda gerçek 90° dönüşü ve küçük ekran/büyük yazılı formu kontrol eder. Koşum seri numarası belirtilmeyen veya fiziksel cihazda display matrisi çalıştırmayı reddeder. Bütün oluşturma/düzenleme işlemleri localhost fixture verisindedir. Google oturumu, ödeme, AI gönderimi veya gerçek kullanıcı verisi kullanılmaz. Testler sonunda display/font/animation override'ları sıfırlanır.

### Kapsam ve sınırlar

API modelleri ve servisleri, auth/session/Google, AssistantService/Gemini, kredi tüketimi, IAP/RevenueCat/Play Billing, tracking ve bildirim iş kuralları, PDF üretimi ve backend dosyalarında değişiklik yoktur. Mevcut functional suite geçti. Gerçek Google oturumu, satın alma, AI analizi, FCM/cihaz bildirimleri, PDF paylaşımı, production API ve fiziksel OEM davranışları bu çalışmada uçtan uca doğrulanmadı. iOS native çalıştırılmadı. Android çalıştırma API 36/x86_64 emülatöründedir; ARM cihaz testi değildir.

Production sürüm/signing/env değişmedi. Önceki `release-artifacts/ekspersiz-1.0.2-54.aab` SHA-256 değeri hâlâ `bb9d794138becf7694d4534ebb77bbbf8abff8d065c80ce1bc45f7465146ee56`. Bu UI çalışması production sürümü yayımlamaz veya versionCode tüketmez.
