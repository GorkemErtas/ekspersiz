# EksperSiz — React Native geliştirme ve test

Flutter referansı `../mobile/`, Expo uygulaması bu dizindedir. Ana kabuk, araç/bakım/hatırlatıcı yönetimi, iki fotoğrafla analiz, rapor/tutanak PDF’leri, asistan, Business, bildirim ve mağaza akışları gerçek API/native SDK bağlantılarıyla uygulanmıştır. Doğrulananlarla harici ortam gerektiren kontrolleri [migration durumunda](../docs/migration/FLUTTER_TO_REACT_NATIVE.md) ayrı okuyun. Varsayılan kimlik `.dev` olarak kalır; Android production derlemesi doğrulanmış girdiler ve mevcut upload key ile [release akışından](../docs/production/ANDROID_RELEASE.md) yapılır. Eksik girdilerde production açık hatayla durur.

Güncel yayın engelleri, hardening düzeltmeleri, CI kontrolleri ve manuel kabul matrisi: [Production readiness audit](../docs/production/READINESS_AUDIT.md).

## Gereksinimler

| Bağımlılık                  | Kullanılan/doğrulanan sürüm                                                                              |
| --------------------------- | -------------------------------------------------------------------------------------------------------- |
| Node                        | `.nvmrc`: **24.21.0**; sistemdeki 22.12 bu SDK için eski                                                 |
| Expo / React Native / React | 58.0.21 / 0.88.1 / 19.3.0; kesin bağımlılıklar `package-lock.json` içinde                                |
| Java                        | Android Studio JBR / **JDK 21** ile derlendi                                                             |
| Android SDK                 | Platform **37**, build-tools **37.0.0**, platform-tools                                                  |
| NDK / CMake                 | **27.1.12297006 / 3.31.6**; Windows uzun dosya yollarında eski Ninja/CMake kullanmayın                   |
| Android test cihazı         | API 24+; cihaz kontrolleri API **36**, x86_64 Google API emülatöründe yapıldı                            |
| iOS                         | macOS, SDK 58 ile uyumlu Xcode/iOS SDK, CocoaPods ve imzalama; Windows’ta iOS native derlemesi yapılamaz |

Normal React Native geliştirmesi için Flutter kurmak gerekmez. Flutter SDK yalnızca referans görselleri/katalogları yeniden üretirken gerekir. **Expo Go kullanmayın:** özel native modül, Firebase, RevenueCat, harita ve konuşma tanıma için development build gerekir.

## Android — ilk çalıştırma

PowerShell’i Node 24’ün PATH’te olduğu bir terminalde açın:

```powershell
cd C:\vehicleinspector\vehicle-inspector\mobile-rn
node --version
npm ci
Copy-Item .env.example .env.local
```

`.env.local` içindeki `EXPO_PUBLIC_API_BASE_URL` değerini erişilebilir **yerel veya staging backend** adresine, `/api/v1` dahil olacak şekilde ayarlayın. E-posta/şifre girişi için backend’in veritabanı ve e-posta ayarları da hazır olmalıdır; mevcut backend kurulumunu kullanın.

```powershell
$env:JAVA_HOME = 'C:\Program Files\Android\Android Studio\jbr'
$env:ANDROID_HOME = "$env:LOCALAPPDATA\Android\Sdk"
$env:PATH = "$env:JAVA_HOME\bin;$env:ANDROID_HOME\platform-tools;$env:PATH"
```

Android Studio > SDK Manager üzerinden yukarıdaki SDK/NDK/CMake bileşenlerini kurun. İsterseniz kurulu command-line tools ile:

```powershell
& "$env:ANDROID_HOME\cmdline-tools\latest\bin\sdkmanager.bat" 'platforms;android-37' 'build-tools;37.0.0' 'ndk;27.1.12297006' 'cmake;3.31.6' 'platform-tools'
& "$env:ANDROID_HOME\cmdline-tools\latest\bin\sdkmanager.bat" --licenses
npx expo install --check
npx expo prebuild --platform android --no-install
adb devices
npm run android -- --device
```

Bir emülatör açın veya USB debugging açık bir geliştirme cihazı bağlayın. Uygulama kimliği **`com.gorkem.ekspersiz.dev`**; Flutter kurulumu ile birlikte bulunabilir. İlk native derleme bağımlılık indirmeleri ve C++ derlemeleri nedeniyle uzun sürebilir. Sonraki yalnızca JS/TS değişikliklerinde Metro yeterlidir:

```powershell
adb reverse tcp:8081 tcp:8081
npm run start -- --localhost
```

Emülatörden bilgisayarın backend’ine `http://10.0.2.2:8080/api/v1` ile erişilir. USB cihazında `adb reverse tcp:8080 tcp:8080` kullanıp API adresini `http://127.0.0.1:8080/api/v1` yapabilirsiniz; staging HTTPS adresi de kullanılabilir. Wi-Fi erişiminde cihazın ulaşabildiği adres gerekir.

Native paket/plugin/Firebase/harita ayarı değiştiğinde `prebuild` ve `npm run android` tekrar gerekir. API ortamını değiştirince Metro’yu kapatıp yeniden açın. Eski kod veya yanıt vermeyen Metro durumunda:

```powershell
npx expo start --dev-client --localhost --clear
```

`--offline` ve `--localhost` birlikte verilmez; offline seçeneği zaten localhost kullanır. Yerel derleme için EAS projesi veya bulut build gerekmez.

## Servis yapılandırmaları

Boş bırakılan servisler başarılıymış gibi davranmaz; ilgili özellik hata veya kullanılamaz durumu gösterir. SDK yapılandırması olmayan ortamda hesap/araç gibi bağımsız özellikler çalışabilir.

| Özellik                   | Gerekli ayar                                                                                                                                                                                                                                                                                       |
| ------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Google giriş              | `EXPO_PUBLIC_GOOGLE_WEB_CLIENT_ID`; Android’de `.dev` paket adı ve debug imzasının SHA-1’iyle kayıtlı OAuth istemcisi. iOS’ta ayrıca `EXPO_PUBLIC_GOOGLE_IOS_CLIENT_ID`, `GOOGLE_IOS_URL_SCHEME`                                                                                                   |
| Firebase/FCM              | `.dev` uygulamasına ait geliştirme Firebase dosyaları: `GOOGLE_SERVICES_FILE=./secrets/google-services.json`, `GOOGLE_SERVICES_PLIST=./secrets/GoogleService-Info.plist`. Gerçek FCM token’ı backend’e kaydedilir. Android 13+ bildirim izni; iOS’ta APNs anahtarı/capability/provisioning gerekir |
| Google Maps               | Platforma ve uygulama/imzaya kısıtlı `EXPO_PUBLIC_GOOGLE_MAPS_ANDROID_API_KEY`, `EXPO_PUBLIC_GOOGLE_MAPS_IOS_API_KEY`; Maps SDK’larını açın. Yakındaki servis araması backend’in Places yapılandırmasını kullanır. Native harita anahtarı yoksa servis listesi ve haritada açma bağlantısı çalışır |
| RevenueCat                | `EXPO_PUBLIC_REVENUECAT_ANDROID_PUBLIC_KEY` (`goog_` veya test mağazası `test_`), iOS karşılığı (`appl_`/`test_`). Offering/package/SKU’lar mevcut backend kataloğuyla eşleşmeli; backend RevenueCat doğrulaması/webhookları hazır olmalı. Gerçek mağaza fiyatı yokken satın alma açılmaz          |
| Android başlangıç kredisi | Backend’in `/credits/welcome/challenge` yanıtındaki gerçek Cloud project number/request hash, Standard Play Integrity ve uygun Play dağıtımı. `ANDROID_ID` native’den alınır; sahte cihaz kanıtı üretilmez                                                                                         |
| Zorunlu güncelleme        | Backend `/app/version` + gerçek Play immediate update; ADB ile yüklenen geliştirme APK’sı Play üzerinden dağıtım testinin yerine geçmez                                                                                                                                                            |
| Sesli asistan             | Mikrofon/konuşma izni ve cihazda Türkçe tanımayı destekleyen sistem sağlayıcısı; emülatörde sağlayıcı bulunmayabilir                                                                                                                                                                               |

`secrets/` ve `.env.local` git dışında kalır. `EXPO_PUBLIC_*` değerleri uygulamaya gömülür; backend servis hesabı, model sağlayıcı anahtarı veya RevenueCat secret key bu değişkenlere konulmaz. RevenueCat public SDK key biçimi build sırasında denetlenir. Production Firebase dosyasını `.dev` kimliği için yeniden kullanmayın.

Mağaza testini Play Internal Testing / StoreKit sandbox ve test kullanıcılarıyla yapın. Mağaza ödemesi tek başına kredi/Business erişimi vermez: sunucu sync ve transaction confirmation gerekir. Yanıtı kaybolan kredi alımı şifreli bekleyen işlem kaydından uzlaştırılır; aynı SKU yeniden tahsil edilmez. Kesin sonucu bilinmeyen işlemde mağaza/RevenueCat/backend işlem kaydı kontrol edilmeden yerel kaydı silmeyin.

## iOS

macOS’ta aynı lockfile ve `.env.local` ile:

```sh
npm ci
npx expo prebuild --platform ios
npm run ios
# Fiziksel cihaz:
npm run ios -- --device
```

Xcode’da development team, `.dev` bundle ID, Firebase/APNs ve gerekli capability/provisioning ayarlarını tamamlayın. iOS Swift modülü, APNs, mağaza satın alımı ve VoiceOver **bu Windows ortamında doğrulanmadı**. JavaScript iOS bundle kontrolü native derleme kanıtı değildir.

## Otomatik kontroller

```powershell
npm run typecheck
npm run lint
npm test
npm run format:check
npx expo install --check
npx expo-doctor
npm audit
npx expo export --platform android --output-dir dist/android
npx expo export --platform ios --output-dir dist/ios
```

Testler oturum/çalışma alanı yarışlarını, özel medya sınırlarını, tek ödeme/uzlaştırmayı, asistan request ID’sini, GPS temizliğini, tracking payload’larını ve gerçek Türkçe fontlarla PDF sayfalamayı kapsar. `npm audit` için kalan bulgular [migration belgesinde](../docs/migration/FLUTTER_TO_REACT_NATIVE.md) açıkça listelenir; tüm güvenlik kontrollerinin geçtiği varsayılmamalıdır.

Emülatöre uygun tek mimarili native derleme:

```powershell
cd android
.\gradlew.bat :app:assembleDebug -PreactNativeArchitectures=x86_64 -x lint -x test --no-daemon --max-workers=2
cd ..
```

Fiziksel ARM64 cihaz için `-PreactNativeArchitectures=arm64-v8a` veya Expo’nun normal `npm run android` komutunu kullanın. Gradle komutundaki `-x test`, native paketlerin testlerini atlar; üstteki Jest testlerinin yerine geçmez.

## Anahtar gerektirmeyen native arayüz karşılaştırması

`visual/fixture-server.mjs` yalnızca **127.0.0.1:18080** üzerinde, sentetik verilerle çalışan açık test taşımasıdır; production modu reddedilir. Uygulama bu dosyayı import etmez. Bu mod gerçek AI, ödeme, e-posta veya FCM başarısının kanıtı değildir.

İlk terminal:

```powershell
node visual/fixture-server.mjs
```

İkinci terminal:

```powershell
$env:EXPO_PUBLIC_API_BASE_URL = 'http://127.0.0.1:18080/api/v1'
adb -s emulator-5554 reverse tcp:18080 tcp:18080
adb -s emulator-5554 reverse tcp:8081 tcp:8081
npx expo start --dev-client --offline --port 8081
```

Geliştirme uygulamasını açın; fixture girişinde `deniz@example.com` / `FixtureOnly123` kullanılabilir. Kamera/galeri için gerçek native seçim ekranı ve özel native fotoğraf hazırlama modülü çalışır; sadece backend yanıtları sentetiktir. Rehber ilk kurulumda açılır; sonradan Profil’den tekrar erişilebilir.

Ekran yakalama ve Flutter karşılaştırması için [VISUAL_PARITY.md](../docs/migration/VISUAL_PARITY.md) dosyasındaki cihaz boyutu/tema/fixture adımlarını izleyin. İlk Metro bundle’ının tamamlanmasını bekleyin. Test bitince iki sunucuyu kapatın, süreçteki `EXPO_PUBLIC_API_BASE_URL` override’ını kaldırın ve normal backend ile Metro’yu yeniden başlatın.

## Cihazda elle tamamlanacak testler

Giriş/kayıt/doğrulama/şifre yenileme; araç oluştur–düzenle–ana araç seç–kaldır; bakım/hatırlatıcı CRUD; konum izni reddet/izin ver; farklı iki fotoğraf–analiz–ek fotoğraf–rapor; taslak–kesinleştir–PDF paylaş; asistan araç/genel bağlam, sesli giriş, iptal ve aynı isteği yeniden kontrol et; OWNER/MEMBER, davet/katıl/üyeyi kaldır, Business erişim süresi dolması; mağaza iptal/bekleyen/restore/yenileme; FCM foreground/background/terminated ve hesap değişimi; geniş ekran/yazı büyütme/tema/ekran okuyucu senaryolarını gerçek staging servisleriyle kontrol edin. Özellikle ücretli işlemleri fixture başarısıyla kabul etmeyin.
