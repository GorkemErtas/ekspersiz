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
node scripts/android-cold-start.mjs emulator-5556 release-artifacts/ekspersiz-1.0.2-54.apk release-artifacts/ekspersiz-1.0.2-54.aab com.gorkem.ekspersiz 54 release-artifacts/cold-start-clean-emulator-54
```

Fiziksel cihaz için ilk argümana açık cihaz seri numarası, son argümana ayrı bir kanıt klasörü verilir. Script `install -r` yapar; uninstall veya uygulama verisi silme yapmaz. Her üç denemede force-stop ile süreç kapatılır, MainActivity başlatılır, React Native onboarding/giriş ekranının UI XML'de görünmesi ve foreground Activity doğrulanır, süreç 10 saniye daha izlenir, logcat/ANR kontrol edilir. Screenshot, UI XML, Activity dökümü, logcat ve artifact hash'leriyle `cold-start.json` git dışında kaydedilir. Emülatör sonucu fiziksel cihaz sonucu olarak işaretlenmez.

Play App Signing sertifikası upload sertifikasından farklıdır. Play'den kurulmuş 53 üzerine upload key ile imzalanmış yerel APK doğrudan kurulamaz; mevcut kurulum/veri otomatik silinmez. Yerel fiziksel cold-start testi de Play tarafından dağıtılan güncelleme, Google Login veya Integrity kabulünün yerine geçmez. Bu görev kapsamında Play yüklemesi veya production deploy yapılmaz.

CI release job'u aynı ProGuard/DEX denetimlerini ve API 36 x86_64 emülatöründe üç cold-start denemesini çalıştırır. CI paketi `.dev` kimliğinde ve production girdileri olmadan üretilir; production AAB kanıtları ayrıca yerel release raporuna yazılır.

CI'deki açık `expo install --check` adımı, yalnızca bu adımda `EXPO_OFFLINE=1` ile lockfile'daki Expo'nun `bundledNativeModules.json` uyumluluk haritasını denetler. Uzak API'nin yeni `58.0.22 / build-properties 58.0.12 / dev-client 58.0.18 / router 58.0.29` patch önerileri bu crash düzeltmesine dependency yükseltmesi eklemez. Kontrol devre dışı değildir: kurulu paketler geçti; izole sentetik projede yanlış `react-native 0.0.1` aynı offline komutla exit 1 / `upToDate=false` olarak reddedildi. Online security audit adımı korunur. Patch güncellemeleri ayrı bir değerlendirmedir.

## Doğrulama sonuçları

| Kontrol                             | Sonuç                                                                                                                                                                                                       |
| ----------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| TypeScript / ESLint / Expo config   | Geçti                                                                                                                                                                                                       |
| Script regresyonları                | 13/13 geçti; sürüm ve startup manifest kontrolleri de geçti                                                                                                                                                 |
| Jest                                | 18 suite, 118 test geçti. Native build ile paralel ilk koşudaki PDF süre aşımı tam tekrar koşusunda tekrarlanmadı.                                                                                          |
| Production AAB / APK / release lint | `npm run release:android -- --apk` geçti; 1.248 imzalı giriş, 87 native kütüphane, üç ABI, Hermes ve ELF 16 KiB kontrolü geçti                                                                              |
| ProGuard / optimize DEX             | Generated ve effective kurallar, üç public `()V` constructor, SDK `dexdump` kontrolü geçti                                                                                                                  |
| APK manifest / ZIP hizalaması       | `aapt`: production paket, 1.0.2 (54), minSdk 24 / targetSdk 36 ve üç ABI; `zipalign -c -P 16 4` geçti                                                                                                       |
| APK / emülatör cold-start           | **3/3 geçti.** İzole API 36 x86_64 AVD'de üç farklı süreç, `LaunchState: COLD`, RN onboarding ve resumed MainActivity; her süreç en az 10 saniye ayakta, logcat'te crash/ANR yok. Screenshot'lar incelendi. |
| APK / AAB eşleşmesi                 | İki artifact'ın `classes.dex` SHA-256 değerleri birebir eşleşti; üç public parametresiz constructor ikisinde de doğrulandı                                                                                  |
| Fiziksel cihaz cold-start           | Bekliyor; bağlı Samsung'da Play 53 kurulumu görüldü, sonra cihaz ADB listesinden ayrıldı. Mevcut kurulum/veri silinmedi.                                                                                    |

Mevcut emülatörde farklı imzalı Flutter 52 kurulu olduğu için test aracı `INSTALL_FAILED_UPDATE_INCOMPATIBLE` ile durdu; kurulum/veri silinmedi. Başarılı test yeni `Ekspersiz_WorkManager_54_20261031` AVD'sinde yapıldı. Bu **temiz kurulum testi**, mevcut Flutter/Play kurulumunun yerinde güncellenmesi değildir. Windows logcat yakalaması cihazın epoch zamanı ve doğrudan `adb shell logcat` ile doğrulandı.

| Artifact       | Yerel yol (`mobile-rn/` altında)           |           Boyut | SHA-256                                                            |
| -------------- | ------------------------------------------ | --------------: | ------------------------------------------------------------------ |
| Production AAB | `release-artifacts/ekspersiz-1.0.2-54.aab` | 68.628.712 bayt | `bb9d794138becf7694d4534ebb77bbbf8abff8d065c80ce1bc45f7465146ee56` |
| Optimize APK   | `release-artifacts/ekspersiz-1.0.2-54.apk` | 90.905.848 bayt | `3376e9a58b85cd2ec6262ec7362b13ea26873d93c58657c59d6bf236f81bf1f7` |

Ortak DEX SHA-256: `25b93bc8a39e1e2d1c9b230fc9b69efeca603838e9e489047804d8694fda79d5`. Upload sertifikası SHA-256: `1E1689B271621619851BA875CE835294E667BA91301C16B7A530188D079B2732`; 53 ile aynı mevcut Flutter upload key.

İmza/native/R8 raporu: `release-artifacts/ekspersiz-1.0.2-54-verification.json`. Çalışma zamanı kanıtları: `release-artifacts/cold-start-clean-emulator-54/cold-start.json` ve aynı klasörde her denemenin PNG, UI XML, Activity ve logcat kayıtları. Rapor `physicalDevice=false` olarak işaretlidir.

**Fiziksel cihaz cold-start kanıtı bekliyor; yayın kabulü NO-GO ve PR taslaktır.** Emülatör başarısı fiziksel cihaz kabulü sayılmaz. Play'e yükleme, master'a merge ve production deploy yapılmadı.
