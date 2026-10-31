# Android açılış çökmesi: WorkManager / R8 — 31 Ekim 2026

Başlangıç: güncel `origin/master`, `f47b34d`. Çalışma branch'i: `fix/android-release-workmanager-crash`. Aday: `com.gorkem.ekspersiz`, **1.0.2 (54)**. Uygulama sahibi 31 Ekim 2026'da tüm Play track/taslakları ve App Bundle Explorer için maksimum versionCode'u **53** olarak Console'dan doğruladı. Bu oturumda doğrudan Play Console erişimi yoktur.

## Kök neden ve dar kapsamlı düzeltme

Yerel paketler: Expo **58.0.21**, React Native **0.88.1**, expo-build-properties **58.0.11**, react-native-maps **1.29.11**, AGP **9.2.1**, Gradle **9.4.1**. Bu projede WorkManager'ın giriş noktası `react-native-maps/android/build.gradle` içindeki `androidx.work:work-runtime:2.9.1` bağımlılığıdır; `expo-widgets` kullanılmıyor. WorkManager, Room **2.5.0** getiriyor.

53 numaralı gerçek production AAB'nin SHA-256 değeri `289b812d8649b038d5138dd8d548f99a9f16cb571d7fd18ec8db00f7b8d8d78b`. Bu AAB'nin derlenmiş `base/dex/classes.dex` çıktısında:

| Sınıf                                    | Tanımlı method sayısı | `<init>` |
| ---------------------------------------- | --------------------: | -------- |
| `androidx.work.impl.WorkDatabase_Impl`   |                     7 | Yok      |
| `androidx.work.OverwritingInputMerger`   |                     0 | Yok      |
| `androidx.work.ArrayCreatingInputMerger` |                     0 | Yok      |

R8'nin eski `configuration.txt` çıktısında Room ve InputMerger consumer kuralları yalnızca sınıfı tutuyor, constructor üyesini belirtmiyor. AndroidX Startup provider'ı WorkManager'ı React Native başlamadan başlatıyor. Room'un reflection ile çağırdığı public parametresiz constructor silindiği için fiziksel cihaz logundaki `Unable to get provider androidx.startup.InitializationProvider / Failed to create an instance of class androidx.work.impl.WorkDatabase.canonicalName` oluşuyor. Bu bulgular [Expo #51337](https://github.com/expo/expo/issues/51337) ve [#52173](https://github.com/expo/expo/issues/52173) ile uyumlu.

53 mapping dosyasının `pg_map_id` değeri `247a0dda764676b9fcc8fdc07e320ac2c5a6e3b633986ea3bda87e35a7a49f2a`; fiziksel crash logundaki `r8-map-id` ile birebir eşleşiyor. Orijinal WorkManager 2.9.1 AAR'sının `classes.jar` dosyasında `javap` üç constructor'ın da public ve parametresiz olduğunu doğruluyor. Kaynak AAR'de bulunan constructor'lar 53'ün optimize DEX'inde yok; 54'ün optimize DEX'inde ise Java guard ve Android SDK `dexdump` ikisi de üçünde `()V`, `0x10001 (PUBLIC CONSTRUCTOR)` doğruluyor. R8 sürümü her iki build'de **9.2.14**.

Kalıcı kaynak `mobile-rn/app.config.ts` içindeki mevcut `expo-build-properties.android.extraProguardRules` ayarıdır:

```proguard
-keep class * extends androidx.room.RoomDatabase { <init>(); }
-keep class * extends androidx.work.InputMerger { <init>(); }
```

Kurallar `expo prebuild` ile generated `android/app/proguard-rules.pro` dosyasına yazılır. R8 full mode, minify, resource shrinking, Hermes, mevcut upload key, production servis girdileri ve backend korunur. Dependency/lockfile yükseltmesi yoktur. Generated native dosyalar commit edilmez.

## Tekrarlanabilir regresyon kontrolü

Node sürümü `.nvmrc` ile **24.21.0**, Java **21**. Mevcut, ignored `.env.production.local` dosyasında yalnızca release metadata `1.0.2 / 54 / Play max 53` olarak güncellenir. Diğer servis/signing girdileri değiştirilmez.

```powershell
cd mobile-rn
npm run test:ci-scripts
npm run typecheck
npm run lint
npm run check:config
npm test -- --ci
npm run release:android -- --apk
```

Normal `npm run release:android` akışı generated ve effective R8 kurallarını, optimize AAB içindeki üç public parametresiz constructor'ı, Hermes bytecode'u, tüm AAB girişlerinin imzasını, ARM32/ARM64/x86_64 varlığını, 64-bit ELF 16 KiB hizalamasını, release manifestini ve lint'i denetler. Başarısız constructor denetiminde yeni AAB kabul edilmez.

`--apk` ayrıca aynı release varyantının APK'sını üretir; APK imzasını mevcut upload sertifikasıyla ve **tüm DEX SHA-256 değerlerini AAB ile** karşılaştırır. Test APK'sı, farklı debug build'inden alınamaz.

```powershell
node scripts/android-cold-start.mjs emulator-5554 release-artifacts/ekspersiz-1.0.2-54.apk release-artifacts/ekspersiz-1.0.2-54.aab com.gorkem.ekspersiz 54 release-artifacts/cold-start-emulator-54
```

Fiziksel cihaz için ilk argümana açık cihaz seri numarası, son argümana ayrı bir kanıt klasörü verilir. Script `install -r` yapar; uninstall veya uygulama verisi silme yapmaz. Her üç denemede force-stop ile süreç kapatılır, MainActivity başlatılır, React Native onboarding/giriş ekranının UI XML'de görünmesi ve foreground Activity doğrulanır, süreç 10 saniye daha izlenir, logcat/ANR kontrol edilir. Screenshot, UI XML, Activity dökümü, logcat ve artifact hash'leriyle `cold-start.json` git dışında kaydedilir. Emülatör sonucu fiziksel cihaz sonucu olarak işaretlenmez.

Play App Signing sertifikası upload sertifikasından farklıdır. Play'den kurulmuş 53 üzerine upload key ile imzalanmış yerel APK doğrudan kurulamaz; mevcut kurulum/veri otomatik silinmez. Yerel fiziksel cold-start testi de Play tarafından dağıtılan güncelleme, Google Login veya Integrity kabulünün yerine geçmez. Bu görev kapsamında Play yüklemesi veya production deploy yapılmaz.

CI release job'u aynı ProGuard/DEX denetimlerini ve API 36 x86_64 emülatöründe üç cold-start denemesini çalıştırır. CI paketi `.dev` kimliğinde ve production girdileri olmadan üretilir; production AAB kanıtları ayrıca yerel release raporuna yazılır.

## Doğrulama sonuçları

| Kontrol                           | Sonuç                                                                                                                    |
| --------------------------------- | ------------------------------------------------------------------------------------------------------------------------ |
| TypeScript / ESLint / Expo config | Geçti                                                                                                                    |
| Script regresyonları              | 13/13 geçti; sürüm ve startup manifest kontrolleri de geçti                                                              |
| Jest                              | 18 suite, 118 test geçti. Native build ile paralel ilk koşudaki PDF süre aşımı tam tekrar koşusunda tekrarlanmadı.       |
| Production AAB / release lint     | `npm run release:android` geçti; 1.248 imzalı giriş, 87 native kütüphane, üç ABI, Hermes ve ELF 16 KiB kontrolü geçti    |
| ProGuard / optimize DEX           | Generated ve effective kurallar, üç public `()V` constructor, SDK `dexdump` kontrolü geçti                               |
| APK / emülatör cold-start         | Devam ediyor; henüz başarı iddiası yok                                                                                   |
| Fiziksel cihaz cold-start         | Bekliyor; bağlı Samsung'da Play 53 kurulumu görüldü, sonra cihaz ADB listesinden ayrıldı. Mevcut kurulum/veri silinmedi. |

İlk AAB ve doğrulama kaydı `mobile-rn/release-artifacts/ekspersiz-1.0.2-54.aab` ve `ekspersiz-1.0.2-54-verification.json` içinde yerel olarak hazır. APK ve fiziksel cihaz testi tamamlanana kadar çalışma **yayın kabulü almış sayılmaz**. Play'e yükleme, master'a merge ve production deploy yapılmadı.
