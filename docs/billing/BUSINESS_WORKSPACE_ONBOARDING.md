# Business satın alma ve şirket kurulumu

26 Ekim 2026; incelenen master: `d8109f6`. Bu çalışma deploy, Railway değişikliği,
gerçek satın alma veya master merge içermez.

## Kanıtlanan kök nedenler

İlk incelemede master üzerindeki satırlar:

| Kanıt | Sonuç |
| --- | --- |
| Java `BillingService.java:192` içindeki `!subscription.sandbox()` ve satır 149 webhook sandbox dönüşü | Sandbox aboneliği bilerek reddedilir. Sync başka aktif production plan bulamazsa `expireSubscription` (`:274`) FREE yazar. Store başarısı Business hakkı değildir. |
| Flutter `subscription_screen.dart:130–138` | BUSINESS sync sonucunda yalnız başarı mesajı verilir; şirket onboarding'i, üyelik yenileme ve workspace seçimi yoktur. |
| `BusinessAccountService.java:49–84` | Şirket yalnız BUSINESS kullanıcı ve mevcut üyelik yoksa açık oluşturma isteğiyle açılır; ödeme şirket oluşturmaz. |
| `workspace_session.dart:69–76` | Aynı kullanıcının PERSONAL seçimi üyelik yenilenince de korunur. Aboneliğin BUSINESS olması tercihi değiştirmez. |
| `main_shell.dart:167` | Her workspace metadata yenilemesi açık route'ları kapatır; yeni üyelik onboarding'i de kesebilir. |
| Flutter `BillingService.purchase` ve `restore` | Native müşteri kimliği ekran yüklenmesindeki yapılandırmaya dayanır; işlem anında sunucu müşterisi yeniden doğrulanmalıdır. |

Gerçek müşterinin RevenueCat/Play işlemi ve production veritabanı bu çalışma
sırasında okunmadı. Kullanıcının somut işleminin sandbox olduğu, SKU'su, ödeme
durumu veya süresi varsayılmıyor. Bu tablo kod davranışının kanıtıdır.

## Durumlar ve yeni akış

1. Store sonucu yalnız ödeme panelinin sonucudur. Flutter, backend üretimi
   `billingCustomerId` ile RevenueCat kimliğini kurar. Katalogdaki
   `business_monthly` alias'ının SKU'su `eksper_business_monthly` veya
   `eksper_business_monthly:<base-plan>` olmalıdır.
2. `/billing/sync` secret anahtarla RevenueCat `/subscribers/{billingCustomerId}`
   verisini okur. Bilinen SKU, sandbox, refund ve dönem/grace bitişi mevcut backend
   kurallarıyla değerlendirilir. Webhook gecikmiş olsa da sync uzlaştırabilir.
3. Sync yanıtında `status.currentPlan` effective plan'dır. Eklenen
   `status.verificationStatus` yalnız tanısal sonuçtur: `VERIFIED`,
   `SANDBOX_REJECTED`, `NO_ACTIVE_SUBSCRIPTION`. Salt GET `/billing` sonucu
   `NOT_CHECKED` döner. Bu alan yetki üretmez, ledger'a yazılmaz ve migration
   gerektirmez. Eski mobil sürümler ek alanı yok sayabilir.
4. BUSINESS doğrulanınca `/auth/me` güncel üyeliği okur. Üyelik varsa OWNER/MEMBER
   rolüyle mevcut şirket kullanılır. Yoksa **Şirketini oluştur** ekranı açılır.
   Şirket adı kullanıcıdan alınır; kullanıcı **Şirketi Oluştur** demeden POST yoktur.
5. Oluşturmadan hemen önce `/auth/me` başka cihazdaki üyelik değişimini kontrol
   eder. Şirket oluşturulduktan sonra `/auth/me` üyeliği yeniden yükler ve
   WorkspaceSession metadata'sını günceller. Sonra BUSINESS header'ıyla
   `/workspace` kullanıcı/şirket/type ve response header'ını doğrular; başarılıysa
   yerel Business tercihi kaydedilir. Mevcut backend tek üyelik kısıtı korunur.
6. Üyelik eklenmesi Personal'daki onboarding route'unu kapatmaz. Alan değişimi,
   eski üyeliğin kaldırılması/değişmesi veya rol değişimi eski route'ları kapatır.
   Plan metadata'sı yenilenmesi tek başına devam eden satın alma scope'unu bozmaz.
7. Kurulum kapanır veya oluşturma/üyelik yenileme/geçiş başarısız olursa aktif
   abonelik yeniden satın alınmaz. Ekran tekrar açılınca sync yapılır ve kurulum
   düğmesi görünür. POST başarılı olup yanıt/sonraki refresh kaybolduysa sonraki
   deneme mevcut üyeliği bulur. Store katalog hatası da doğrulanmış planı gizlemez.

Pending, iptal ve backend hatası Business etkinleştirmez. Bekleme/sandbox nedeni
ekranda kalır; **Yeniden kontrol et** yalnız sync/bakiye okur, ödeme başlatmaz.
Abonelik durumu ve **Aktif çalışma alanı** ayrı metinlerle gösterilir.

Kişisel araçlar, analizler ve `user:{id}` cüzdanı şirkete taşınmaz. Şirketin
`business:{id}` cüzdanı ve OWNER satın alma kuralları değişmez. Webhook imzası,
refund, renewal, expiration, intent ve idempotency kodu korunur.

## Sandbox sınırı ve güvenli test

`BILLING_SANDBOX_CUSTOMER_IDS` yalnız mevcut kişisel consumable testleri içindir;
Business aboneliğini veya şirket cüzdanını açmaz. Bu yamada genel sandbox izni,
yeni ortam bayrağı veya production hak yazımı eklenmedi.

Yerel testler native ödeme/RevenueCat sınırlarını kontrollü taklit eder. Backend
service testleri gerçek plan/şirket/auth/workspace zincirini çalıştırır; kredi
testleri yalnız yerel disposable `credit_system_test` veritabanına bağlanır.
Bu testler gerçek ödeme veya canlı webhook doğrulaması değildir.

Gerçek sandbox Business E2E için ayrı test uygulaması, RevenueCat proje/anahtarları,
backend ve disposable veritabanı gerekir. Production kullanıcıları/cüzdanları,
anahtarları veya webhook endpoint'i paylaşılmamalıdır. Yalnız bu izolasyonun
garanti edildiği ayrı test backend'inde sandbox kabulü tasarlanmalıdır; mevcut
production backend bu kullanım için açılmamalıdır. Bu çalışma böyle bir ortam
kurmaz veya yayınlamaz. [RevenueCat webhook ortamları](https://www.revenuecat.com/docs/integrations/webhooks).

## Manuel doğrulama

- İlgili hesabın `/billing` yanıtındaki müşteri kimliğini RevenueCat App User ID ile
  yetkili panelde karşılaştırın. Alias'ı tek başına doğrulama saymayın. Secret,
  JWT, ödeme token'ı, raw webhook veya kişisel veri loglamayın.
- Mevcut işlemin SKU/base-plan, `is_sandbox`, purchase/expires/grace/refund ve
  unsubscribe durumlarını kontrol edin. Sandbox ise FREE ve `SANDBOX_REJECTED`
  beklenir. Tekrar satın alma yapmayın.
- Production işlemi zaten mevcutsa `/billing/sync` ardından BUSINESS bekleyin;
  webhook authorization, ortam filtresi, event ID ve teslim sonucunu panelde
  kontrol edin. Webhook başarısı tek başına güncel üyelik veya workspace değildir.
- Şirketsiz doğrulanmış hesapta onboarding'i kapatıp uygulamayı yeniden açın;
  ödeme paneli olmadan devam edin. Şirket adı boş/geçersizken POST olmamalı.
  Açık onay sonrası `/auth/me` OWNER ve `/workspace` BUSINESS olmalı.
- Mevcut OWNER/MEMBER ile Personal → Business → Personal geçişini deneyin.
  İkinci şirket oluşturulmamalı; kişisel araçlar/analizler/bakiye aynı kalmalı.
  Diğer cihazdan üyelik kaldırıldığında şirket erişimi reddedilmeli.
- Cihazda store pending/cancel, ağ kesilmesi, uygulama resume ve oturum değişimini;
  küçük ekran/büyük yazı/klavyeyle formu kontrol edin. Bu yerel çalışma bunlar için
  canlı satın alma başlatmadı.

## Değişen dosyalar ve yerel doğrulama

Backend:

- `src/main/java/com/gorkem/vehicle_inspector/service/BillingService.java`
- `src/main/java/com/gorkem/vehicle_inspector/dto/response/BillingStatusResponse.java`
- `src/test/java/com/gorkem/vehicle_inspector/BillingServiceTest.java`
- `src/test/java/com/gorkem/vehicle_inspector/BusinessSubscriptionFlowTest.java` (yeni)

Flutter (yollar `mobile/` altında):

- `lib/core/workspace/workspace_session.dart`, `workspace_switcher.dart`,
  `workspace_service.dart` (yeni)
- `lib/features/auth/services/auth_service.dart`
- `lib/features/billing/models/billing_status.dart`,
  `screens/subscription_screen.dart`, `services/billing_service.dart`
- `lib/features/business/screens/business_management_screen.dart`
- `lib/features/home/screens/main_shell.dart`
- `lib/features/profile/screens/profile_screen.dart`
- `test/core/workspace/workspace_session_test.dart`
- `test/features/billing/screens/business_subscription_flow_test.dart` (yeni),
  `subscription_screen_test.dart`, `services/billing_service_test.dart`
- `test/features/profile/screens/profile_screen_test.dart`
- `test/features/workspace/workspace_shell_test.dart`

Dokümantasyon: bu belge, kök `README.md` ve `mobile/README.md`.
`mobile/pubspec.yaml`, endpoint'ler, bağımlılıklar, migration'lar, ledger ve
RevenueCatGateway'in mevcut native satın alma/kimlik kuyruğu değiştirilmedi.

| Kontrol | Sonuç |
| --- | --- |
| `flutter test --no-pub --reporter expanded` | Tam paket: 281 başarılı |
| Son oturum yarışı kontrolünden sonra ilgili Flutter paketleri | 64 başarılı; eklenen 12 satın alma/onboarding widget senaryosu dahil |
| `flutter analyze --no-pub` | Sorun yok |
| İlgili Maven servis/HTTP/kredi testleri | 72 başarılı, 0 atlanan; 23 gerçek PostgreSQL ledger testi dahil |
| `git diff --check` | Başarılı |

Tam Flutter koşusu sonrasında eklenen yenileme beklerken oturum değişimi kontrolü,
64 testlik son ilgili koşuda doğrulandı. Backend son koşusu:

```powershell
.\mvnw.cmd '-Dtest=BillingServiceTest,BusinessSubscriptionFlowTest,BusinessAccountServiceTest,AuthServiceTest,RevenueCatClientTest,RevenueCatWebhookVerifierTest,WorkspaceResolverTest,WorkspaceHttpTest,AnalysisCreditServiceTest,CreditWalletPersistenceTest' '-Dcredit.test.jdbc-url=jdbc:postgresql://127.0.0.1:55440/credit_system_test' '-Dcredit.test.username=report_test' test
```

Yerel loglar ignored `target/business-maven-final.log`,
`target/business-flutter-full.log`, `target/business-flutter-final.log` ve
`target/business-flutter-analyze-final.log` dosyalarındadır. Test PostgreSQL
kümesi yalnız loopback'te kullanıldı ve kontrollerden sonra durduruldu.
