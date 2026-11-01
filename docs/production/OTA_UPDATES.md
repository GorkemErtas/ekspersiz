# EksperSiz — kontrollü OTA (EAS Update) hazırlığı

## Bu değişiklik neyi yapar?

Bu PR, OTA güncellemeleri için **isteğe bağlı Expo kanal/runtime yapılandırması** ve fail-closed testler ekler. Mevcut Google Play AAB'leri OTA almaz. Henüz Expo hesabına bağlanmış gerçek project ID, `expo-updates` paketi, GitHub EXPO_TOKEN, otomatik yayın veya production OTA yoktur. Varsayılan **EXPO_UPDATES_ENABLED=0**.

## Uyum ve güvenlik

- Sadece JS/TS ve bundle asset güncellemeleri için OTA. Yeni native kütüphane, Expo SDK, permission, Android yapılandırması veya native kod değişikliği yeni AAB gerektirir.
- Runtime sürümü doğrudan Android `ANDROID_VERSION_NAME` (x.y.z) ile eşleşir. `versionCode` yalnız Play Store'a yeni AAB yüklerken artar; OTA sırasında artmaz.
- Staging ve production birbirinden ayrı **native kanallardır**: CNG config `updates.requestHeaders['expo-channel-name']` ile kanalı AAB'nin içine gömer. Her yeni staging veya production AAB'nin Play versionCode'u benzersizdir.
- Mevcut upload key, API host kısıtları, Firebase, Play Integrity, RevenueCat ve R8/Hermes release kontrolleri korunur. Expo veya GitHub'a gizli Android signing anahtarını yükleme.
- GitHub master push'unu **otomatik canlı OTA** yapan workflow yazılmadı: yanlış bundle'ın binlerce cihaza gitmesini önlemek için ilk kurulum ve manuel onay gerekecek.

## Tamamlanması gereken bir defalık kurulum

1. `cd mobile-rn` dizininde `npm install -g eas-cli`, `eas login`, `eas whoami` komutlarıyla **kendi Expo hesabında** oturum aç. `eas init` ile tek ve doğru Expo projesine bağlanıp gerçek UUID'yi doğrula.
2. `npx expo install expo-updates` ile **Expo SDK 58'e uyumlu** paketi kur; `package.json` ve `package-lock.json` birlikte commit et. `npm ci`, Node/Jest kontrolleri, Android Gradle release build ve cold-start testlerini doğrula. Bu adım henüz tamamlanmadı.
3. İmzalama/API/Google/Firebase ayarlarını barındıran ignored `mobile-rn/.env.production.local` dosyasına şu değerleri ekle:

```dotenv
EXPO_UPDATES_ENABLED=1
EXPO_UPDATES_PROJECT_ID=<Expo hesabındaki gerçek UUID>
EXPO_UPDATES_CHANNEL=staging
```

4. Tüm Play kanalları ve taslaklarındaki en yüksek versionCode'u **Play Console'dan doğrula**, yeni `ANDROID_VERSION_NAME` + daha yüksek `ANDROID_VERSION_CODE` tanımla. `npm run release:check`, `npm run release:android -- --apk` ile staging kanallı native AAB oluştur. Bu AAB'yi Google Play dahili teste yükle.
5. Expo Update kanalını ve EAS environment değerlerini (özellikle bundle'a giren tüm `EXPO_PUBLIC_*` değişkenlerini) AAB ile eşleştir. `eas update:configure` ile oluşan otomatik değişiklikleri mevcut `app.config.ts` üzerinde körlemesine overwrite etme.

## OTA yayınlama / test

OTA-enabled AAB telefonda açılıyor, oturum, analiz, kredi, ödeme ve bildirim testleri geçiyorsa; Expo EAS Update ortamı ve çalışma zamanı sürümünü **yerel native AAB ile eşleştirerek**:

```powershell
cd C:\vehicleinspector\vehicle-inspector\mobile-rn
eas update --channel staging --platform android --environment production --message "Staging UI doğrulaması"
```

Bu repo production app config değerlendirmesi sırasında gerçek signing/Firebase ve sürüm metadata'sı gerektirir. Bunun için EAS ortamını gelişi güzel kullanıp doğrulamaları kapatma; OTA özel build-time değişken kontrolü ve yayın scripti geliştirilmeden komutun doğrudan çalışacağı varsayılmamalı.

Staging onayından sonra **ayrı** `EXPO_UPDATES_CHANNEL=production` AAB'si oluştur ve Play production'a güvenle yayınla. Mevcut OTA-enabled production binary kurulduktan sonra yalnız uyumlu bundle için:

```powershell
eas update --channel production --platform android --environment production --message "Onaylanan JS güncellemesi"
```

Production otomasyonu daha sonra GitHub environment approval + `EXPO_TOKEN` + test/OTA-only change guard ile eklenmeli. İlk kurulumda otomatik production dağıtımı yapma. Uygulama yenilemeyi açılışta indirip genellikle sonraki açılışta uygular; kullanıcı oturumu sırasında zorla yeniden başlatma uygulanmaz.

## Geri alma ve karar

Hatalı OTA için önceki kararlı bundle'a kontrollü rollback veya yeniden yayın uygulanır. Native initialization crash OTA ile düzeltilemez. Eski Flutter ve OTA etkin olmayan RN AAB'leri güncellemeleri alamaz.

**NO-GO:** gerçek Expo project ID yoksa, paket/lockfile kurulmamışsa, JS bundle native ile uyumsuzsa, değişkenler veya güvenlik testleri başarısızsa, Play'de OTA-enabled AAB henüz yoksa.

Kaynak: https://docs.expo.dev/eas-update/getting-started/ ve https://docs.expo.dev/eas-update/deployment/
