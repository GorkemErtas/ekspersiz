# Production Business abonelik düzeltmesi — 27 Ekim 2026

## Kök neden ve incelenen durum

Çalışma `origin/master` ile aynı `3af6084` üzerinden hazırlandı; PR #38'in şirket
onboarding, açık oluşturma onayı ve workspace doğrulama akışı korundu.
Önceki `BillingService.syncUser` tüm `sandbox=true` abonelikleri eliyordu;
webhook da sandbox abonelikte dönüyordu. `BILLING_SANDBOX_CUSTOMER_IDS` yalnız
kişisel consumable alımlarına uygulanıyordu. Dolayısıyla başarılı Play lisans
satın alımı Business'a dönüşmüyordu. Uyarı bu backend kararının doğru yansımasıydı.

SKU eşlemesi `eksper_business_monthly` ve `eksper_business_monthly:<base-plan>`
biçimlerini zaten destekliyordu. Bu hata için ürün kimliği değiştirilmedi.
Google Play ürünlerinin RevenueCat'te base-plan ile temsil edilmesi resmi
[ürün kurulum dokümanında](https://www.revenuecat.com/docs/getting-started/entitlements/android-products)
açıklanır. Gerçek müşterinin somut transaction kaydı veya RevenueCat paneli bu
çalışmada okunamadı; belirli bir ödeme, ürün veya entitlement ayarı doğrulandı
iddiasında bulunulmuyor.

Railway bağlantısından salt okunur olarak doğrulananlar:

- Proje `ekspersiz`, mevcut tek ortam `production`.
- Backend `ekspersiz-backend`, repo `GorkemErtas/ekspersiz`, dal `master`.
- İnceleme anındaki son deployment `af5ab73e-befb-4f8f-9e04-8b22494aa361`, SUCCESS;
  26 Ekim 2026 21:24 Türkiye saati. Bekleyen yapılandırma değişikliği yoktu.
- `BILLING_SANDBOX_CUSTOMER_IDS`, `REVENUECAT_SECRET_API_KEY` ve
  `REVENUECAT_WEBHOOK_AUTHORIZATION` tanımlı. Bağlantı değerleri gizliyor;
  listenin üyeleri, boş olup olmadığı ve secret doğruluğu doğrulanamadı.
- `REVENUECAT_WEBHOOK_SIGNING_SECRET` değişken adı listede bulunmuyor. Mevcut
  zorunlu Authorization doğrulaması korunuyor; isteğe bağlı imza davranışı değişmedi.

## Uygulanan davranış

| Durum | Sonuç |
| --- | --- |
| Doğrulanmış aktif gerçek Business | BUSINESS, `sandbox=false`, mevcut şirket/onboarding akışı |
| İzinli canonical müşteri + kendisine ait aktif sandbox Business + gerçek şirket üyeliği yok | BUSINESS, `sandbox=true`, `VERIFIED`; açık onayla izole test şirketi |
| İzinli test şirketinin mevcut OWNER/MEMBER üyeliği | İkinci şirket oluşturulmaz; üyelik ve sunucu workspace doğrulaması kullanılır |
| İzin listesi dışında hesap, farklı/anonim original App User ID veya gerçek şirkete üyelik | Sandbox hakkı verilmez; `SANDBOX_REJECTED` |
| Hem gerçek hem sandbox abonelik | Aktif gerçek abonelik öncelikli; legacy PLUS/PRO dahil gerçek haklar korunur |
| Sandbox PLUS/PRO veya bilinmeyen SKU | Test aboneliği yetkisi verilmez |
| İptal, dönem/grace devam ediyor | Dönem sonuna kadar erişim korunur; otomatik yenileme kapanır |
| Refund, bitiş veya test izninin kaldırılması | Etkin hak kapanır; kişisel kayıtlar/krediler silinmez |

Flutter yalnız backend'in verdiği `billingCustomerId` ile RevenueCat'i yapılandırır
ve native SDK kimliğini kontrol eder. Backend kimliği JWT kullanıcısından türetir;
istemciden müşteri kimliği veya ortam bayrağı kabul etmez. Secret API sorgusu tam
bu canonical ID'ye yapılır. Sandbox Business için ayrıca API yanıtındaki
`original_app_user_id` aynı canonical ID olmalıdır. Production restore/alias
davranışı korunur; alias, sandbox yetkilendirmesi için kullanılamaz.

`is_sandbox` boolean değilse sağlayıcı yanıtı reddedilir. Aktif aylık abonelikte
başlangıç ve sonlu erişim bitişi gerekir. Webhook ortamı eksik/bilinmiyorsa
reddedilir; TEST/TRANSFER kontrol olayları yalnız API'den yeniden doğrulama yapar.

## Kalıcı izolasyon ve maliyet

- Mevcut `billing_subscriptions.sandbox` kaynak ortamını saklar; sona erme bu
  geçmiş kaynak işaretini silmez.
- V18 `business_accounts.sandbox` alanını, sandbox bütçe lookup indeksini ve ortam değiştirmeyi engelleyen
  trigger'ı ekler. Mevcut şirketler `false` kalır. Kullanıcı, abonelik, kredi,
  araç veya analiz silinmez; mevcut migration checksum'ları değiştirilmedi.
- Bir test şirketi gerçek şirkete; gerçek şirket test şirketine dönüştürülemez.
  Test şirketi sahibi gerçek aboneliğe geçerse otomatik şirket/cüzdan dönüşümü
  yapılmaz. Ayrı gerçek şirket ihtiyacı destek tarafından veri ve üyelikler
  korunarak ayrıca planlanmalıdır; üyelik değiştirilmeden tekrar ödeme istenmez.
- `BusinessBillingPolicy` ortak ortam/izin kontrolüdür; mevcut üyelik ve rol
  kontrollerinin üzerine uygulanır. HTTP workspace, doğrudan servis erişimleri,
  cüzdan rezervasyonu/tamamlama ve bildirim alıcıları bu sınırı kullanır.
- Test şirketine davet ve davet kabulü yalnız izinli test hesapları için açılır.
  İzin ve owner aboneliği kabul anında yeniden denetlenir. İzin kaldırılınca
  mevcut test üyeliği de Business verisine erişemez; PERSONAL kullanılabilir.
- Test şirketinin tamamına **bir kez toplam 3 analiz + 10 asistan kredisi**
  ayrılır. `SANDBOX_SUBSCRIPTION` ledger olayları ve sabit idempotency anahtarları
  hızlı yenilemelerin yeni kredi vermesini engeller. Kullanılmayan test hakkı
  expiry'de kapanır; yeniden abonelik/test şirketi dönüşümüyle bütçe yenilenmez.
- 10 araç slotu ile şirket araç/analiz/hatırlatma akışı test edilebilir.
  Test şirketinde ücretli ek paket niyeti oluşturulmaz. Gecikmiş gerçek ek paket
  receipt'i de bu cüzdana işlenmez. Sandbox şirket consumable alımları kapalıdır.
- Kişisel gerçek satın alınmış krediler korunur. Tekrarlanan ücretsiz kişisel
  sandbox consumable alımlarıyla maliyet sınırının aşılmasını da önlemek için,
  canonical test hesabı başına ömür boyu en fazla 100 analiz + 200 asistan + 10
  slot yeni sandbox teslimi kabul edilir. Mevcut SANDBOX ledger teslimleri bu
  bütçeden sayılır; refund bütçeyi yenilemez. Limit üzerindeki test alımı
  kredilendirilmez veya onaylanmış gösterilmez. Gerçek ücretli alımlar bu sınırdan
  etkilenmez. Eski bakiyeler geriye dönük ayrılmaz veya silinmez; Business bütçesi
  kişisel cüzdana aktarılmaz. LEGACY geçmişe sonradan ortam uydurulmaz.
- Workspace kontrolleri yalnız yerel indeksli DB sorguları kullanır. Normal
  ekran yüklemesi bir RevenueCat backend sync'i yapar. Satın alma tıklaması ödeme
  öncesi bir sync ve ödeme kabul edilirse bir sync yapar. Polling döngüsü yoktur.
  SDK'daki aktif ürün yalnız ikinci ödemeyi önler, Business hakkı vermez.
- Kullanıcı satırı kilidi paralel sync/webhook'un eski receipt'i geri yazmasını
  ve iki şirket oluşturmasını önler. Ortam + event ID advisory kilidi eşzamanlı
  duplicate webhook'u tek işler. Cüzdan, refund, işlem sahipliği, dönem ve
  rezervasyon kilitleri korunur. RevenueCat ağı sırasında cüzdan kilidi tutulmaz.

## Railway, RevenueCat ve Play ayarları

Yeni environment variable veya staging servisi gerekmez. Mevcut
`BILLING_SANDBOX_CUSTOMER_IDS` bilinçli olarak Business'a genişletildi; ikinci
bir kimlik listesiyle tutarsız yetkilendirme oluşturulmadı. Tek başına bu liste
şirketi etkinleştirmez: doğrulanmış receipt, canonical sahiplik, şirket ortamı
ve dönem kontrolleri de zorunludur. `*`, e-posta, boolean ve canonical olmayan
UUID başlangıçta reddedilir. Eski `BILLING_ALLOW_SANDBOX` okunmaz.

Operatör, listeyi yalnız ayrı uygulama test hesaplarının backend üretimi
`users.billing_customer_id` değerleriyle doğrulamalıdır; RevenueCat alias'ı veya
Google hesabı e-postası bu listeye yazılmaz. Salt okunur kontrol örneği:

```sql
SELECT u.id, u.billing_customer_id, u.subscription_plan,
       s.sandbox AS subscription_sandbox, s.status, s.current_period_ends_at,
       b.id AS business_id, b.sandbox AS company_sandbox
FROM users u
LEFT JOIN billing_subscriptions s ON s.user_id=u.id
LEFT JOIN business_members m ON m.user_id=u.id
LEFT JOIN business_accounts b ON b.id=m.business_account_id
WHERE u.billing_customer_id = '<canonical-test-customer-uuid>';
```

Mevcut liste doğruysa aynı değerle çalışır. Listeye ekleme/çıkarma operatör
onayıyla yapılır; yeniden başlayan tüm replica'lar aynı listeyi kullanmalıdır.
Yetki kaldırılması yeni yapılandırmayı kullanan süreçte, webhook beklemeden
erişim kontrolüne yansır. Railway bu çalışma sırasında değiştirilmedi.

Panelden doğrulanması gerekenler:

1. Google Play'de doğru uygulama/package için Business ürünü ve aylık base-plan
   etkin olmalı; test Google hesabı License testing listesinde seçili olmalı.
   Test track'e katılım ile license testing aynı şey değildir. Test ödeme
   yöntemleri ve gerçek hesapla kontrol için [Google'ın kılavuzunu](https://developer.android.com/google/play/billing/test)
   izleyin. Ücretli gerçek satın alma ayrıca onaylı cihaz kontrolü gerektirir.
2. RevenueCat Android uygulaması doğru Play uygulamasına/servis hesabına bağlı
   olmalı. Mobil `REVENUECAT_ANDROID_PUBLIC_KEY` bu uygulamanın platform anahtarı
   olmalı; Test Store anahtarı kullanılmamalı. Secret anahtar yalnız backend'de.
3. Ürün `eksper_business_monthly:<gerçek-base-plan-id>` veya mevcut legacy SKU,
   paket `business_monthly` ile uygulamanın seçtiği `credits_v1` offering'inde
   bulunmalı (yoksa mevcut current offering kullanılır). Business ürününün
   entitlement bağlantısını da kontrol edin. Backend hakları SDK entitlement
   bayrağından değil, doğrulanmış ürün/dönem kaydından hesaplar.
4. Satın alımı yapan RevenueCat App User ID, backend canonical ID ile aynı
   olmalı. `original_app_user_id` farklıysa test hakkı açılmaz; kimlik eşlemesini
   destek üzerinden inceleyin, gerçek müşterileri/receipt'leri silmeyin.
5. Mevcut `/api/v1/billing/revenuecat/webhook` endpoint'ine hem sandbox hem
   production abonelik yaşam döngüsü olayları gönderilmeli; Authorization mevcut
   sunucu ayarıyla eşleşmeli. Duplicate event ID'leri korunmalı.
6. Restore için mevcut sahipliği koruyan `Keep with original App User ID`
   ayarını doğrulayın; sandbox override varsa aynı kuralı uygulayın. Paylaşımlı
   alias restore açılmamalı. Bu ayar hesap kurtarma desteği gerektirir;
   [RevenueCat restore davranışları](https://www.revenuecat.com/docs/projects/restore-behavior).

## Yayın sırası ve geri dönüş

1. Değişiklikleri inceleyin; CI kalite kapıları ve DB yedeğini doğrulayın.
   Otomatik Railway kaynağı master olduğundan master merge yayın başlatabilir;
   merge, production deploy ve değişken değişiklikleri için açık onay gerekir.
2. Onaydan sonra backend + V18'i önce yayınlayın. İzin listesini operatörle
   doğrulayın; gerçek şirket sahiplerini test hesabı olarak eklemeyin.
   Flyway başarı/health ve mevcut gerçek müşteri akışını kontrol edin.
3. Flutter sürümünü sonra yayınlayın. Yeni API alanları eklemelidir; eski
   istemci/backend alanları kaldırılmadı. Eski mobil sürüm backend doğrulamasını
   kullanabilir; açık test etiketi ve tekrar ödeme koruması için yeni sürüm önerilir.
   Yerel `pubspec.yaml` hâlâ `1.0.0+50`; mağaza yayını için Play Console'daki son
   build numarasına göre yeni build numarası ve mevcut platform public key
   dart-define ayarları kullanılmalıdır. Bu çalışma mağaza paketi yayınlamaz.
4. Mevcut satın alım için önce Yeniden kontrol et / Restore kullanın. Yetkili
   hesapta BUSINESS + sandbox=true; onaylı şirket oluşturma; PERSONAL ↔ BUSINESS;
   ikinci şirket/ödeme olmaması; 3/10 bütçesinin yenilemede artmaması; yetkisiz
   davet/erişim reddi; iptal/refund/expiry ve listeden çıkarma kontrolü yapın.
5. Sorunda ilk geri dönüş, test hesabı kimliklerini izin listesinden çıkararak
   sandbox Business erişimini kapatmaktır. Kişisel ve gerçek şirket bakiyelerini
   silmeyin; V18'i geri almayın ve ortam bayraklarını değiştirmeyin.
6. **Sandbox durumları oluşturulduktan sonra korumasız eski backend'e dönmeyin.**
   Eski kod `users.subscription_plan=BUSINESS` üzerinden test şirketine gerçek
   dönem kotası verebilir ve test üyesinin iznini yeniden denetlemez. İzolasyon
   kontrollerini taşıyan bir geri dönüş build'i veya bu build üzerinde düzeltme
   kullanın. Henüz hiçbir sandbox subscription/company kaydı yoksa önceki
   backend eklemeli V18 alanını görmezden gelebilir; bu koşul DB'de doğrulanmalıdır.

## Doğrulama kapsamı

Otomatik testler gerçek satın alma ve yetkili/yetkisiz sandbox ayrımı; şirket
oluşturma ve mevcut üyeliği kullanma; source izolasyonu; canonical kimlik/yanlış
ürün; workspace ve kişisel krediler; renewal/cancellation/refund/expiry;
restore/missed webhook; yetki kaldırılması; yarış ve duplicate event senaryolarını
kapsar. Gerçek PostgreSQL testleri V1–V18 migration'larını ve ledger kilitlerini,
JPA testleri paralel sync, duplicate webhook ve şirket oluşturmayı çalıştırır.
Yerel pgvector eksikliği için yalnız test şemasındaki vector alanları REAL[] ile
temsil edilir; production migration'ları değişmez.

| Son kontrol | Sonuç |
| --- | --- |
| Maven `*Test,*IT` + package; üç disposable PostgreSQL DB etkin | 367 toplam: 365 başarılı, 0 hata, 2 atlandı; JAR oluştu |
| Gerçek SQL migration/cüzdan testleri | 31/31 başarılı; V1–V18, sandbox bütçe ve yarış testleri dahil |
| Gerçek JPA persistence testleri | 18/18 başarılı; paralel sync, webhook ve şirket oluşturma dahil |
| Flutter tüm testler | 285/285 başarılı |
| `flutter analyze --no-pub` | Sorun yok |
| Değişen 7 Dart dosyasında format kontrolü | Değişiklik yok, başarılı |
| `flutter build apk --debug --no-pub` | Başarılı; `mobile/build/app/outputs/flutter-apk/app-debug.apk` |
| `git diff --check` | Başarılı |

Atlanan iki test `AiAssistantBusinessConcurrencyIT` ve
`AiAssistantServiceConcurrencyIT`: mevcut `disabledWithoutDocker` koşulu, Docker
bulunamadığı için atladı. Yeni abonelik/cüzdan yarış testleri gerçek yerel
PostgreSQL üzerinde çalıştı ve atlanmadı. Debug APK native derleme kontrolüdür;
üretim anahtarlarıyla gerçek ödeme veya imzalı mağaza yayını değildir.

Tekrarlanabilir backend komutu (PowerShell, yalnız disposable yerel DB'ler):

```powershell
.\mvnw.cmd -B '-Dtest=*Test,*IT' `
  '-Dcredit.test.jdbc-url=jdbc:postgresql://127.0.0.1:55440/credit_system_test' `
  '-Dcredit.test.username=report_test' `
  '-Dinspection.test.jdbc-url=jdbc:postgresql://127.0.0.1:55440/vehicle_inspector_test' `
  '-Dinspection.test.username=report_test' `
  '-Dsecurity.test.jdbc-url=jdbc:postgresql://127.0.0.1:55440/security_audit_test' `
  '-Dsecurity.test.username=report_test' package
```

Yerel loglar `target/sandbox-business-final-backend.log`,
`target/sandbox-business-flutter-full.log` ve
`target/sandbox-business-flutter-analyze.log`; Git'e eklenmez. Test için başlatılan
yerel PostgreSQL süreç sonunda durduruldu. Canlı Play ödeme/RevenueCat panel
kontrolleri ve production deployment bu yerel doğrulamanın kapsamı dışındadır.
Production deploy, Railway değişken güncellemesi veya master merge yapılmadı.
