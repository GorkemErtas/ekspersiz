# Business expiry ve workspace geçiş döngüsü

27 Ekim 2026. Başlangıç: güncel `origin/master`, `5e60131` (PR #38 ve #39 dahil).
Çalışma dalı: `fix/business-workspace-expiry-loop`.

## Kesin kök neden

1. `AuthService.getBusinessAccount` mevcut üyeliği döndürüyor; bu, abonelik bitse
   de saklanması gereken doğru bir üyelik bilgisi. Ancak yanıt şirket alanının
   şu anda erişilebilir olup olmadığını söylemiyordu.
2. Flutter `AuthService.getCurrentUser`, bu üyelik ID/rolünü doğrudan
   `WorkspaceSession.initialize` içine yazıyordu. Session ve switcher yalnız
   `businessId != null` koşuluyla Business seçeneğini kullanılabilir sayıyordu.
3. Backend sandbox expiry/izin kontrolü `/workspace` isteğini 403
   `WORKSPACE_UNAVAILABLE` ile reddediyordu. İstemcinin `revokeBusiness` metodu
   Business üyeliğini yerel durumdan siliyordu.
4. `ProfileScreen._openSubscription`, Krediler ekranından dönüşte `/auth/me`
   çağırıyor; üyelik yeniden yüklenince aynı seçenek tekrar açılıyordu.
   `/auth/me` 200 ile `/workspace` 403 bu farklı iki anlamdan kaynaklanıyordu.
5. Başlangıçtaki kayıtlı workspace tercihi ve MainShell navigation parametreleri
   de üyeliği erişim gibi kullanabiliyordu. Eşzamanlı, aynı workspace'e ait profil
   yanıtlarında yalnız workspace generation kontrolü en yeni profili seçmek için
   yeterli değildi.
6. `BusinessBillingPolicy.allowsAccess` gerçek şirketlerde yalnız sandbox kaynak
   uyumunu kontrol ediyor; production workspace erişiminde owner aboneliğinin
   aktif olmasını zorunlu tutmuyordu. Bu da sandbox ve production expiry
   davranışlarını farklılaştırıyordu.

Bu nedenler kod üzerinden ve gerçek Auth/Profile/Workspace HTTP zinciri ile
regresyon testlerinde doğrulandı. Railway logları veya production DB bu çalışma
sırasında sorgulanmadı; bildirilen log dizisi yukarıdaki akışla uyumlu.

## API ve backend davranışı

Şirket üyeliğinin `id`, `companyName`, `role`, `sandbox` alanları korunur.
Auth/login/Google login/current-user ve şirket oluşturma yanıtına iki ek alan gelir:

```json
{
  "businessAccount": {
    "id": 7,
    "companyName": "Company",
    "role": "MEMBER",
    "sandbox": true,
    "workspaceAvailable": false,
    "workspaceAccessStatus": "SUBSCRIPTION_EXPIRED"
  }
}
```

`workspaceAvailable` yalnız sunucunun `ACTIVE` kararı için true'dur.

| Durum | Erişim |
| --- | --- |
| ACTIVE | Owner'ın geçerli BUSINESS dönemi; kaynak ortamı ve sandbox izinleri uygun |
| SUBSCRIPTION_EXPIRED | Kullanıcı veya korunmuş billing döneminin bitişi geçmiş |
| SUBSCRIPTION_INACTIVE | Aktif Business hakkı yok; dönem dolmadan refund da bu grupta |
| SANDBOX_NOT_AUTHORIZED | Sandbox şirketinde owner veya erişen hesabın canonical test izni yok |
| ENVIRONMENT_MISMATCH | Şirketin kalıcı ortamı ile owner aboneliğinin kaynağı farklı |
| OWNER_UNAVAILABLE | Geçerli tek şirket sahibi doğrulanamıyor |
| UNKNOWN | Erişilebilirlik doğrulanmamış; erişim kapalı |

Hem OWNER hem MEMBER için karar şirket sahibinin hakkından hesaplanır. Üyenin
kendi FREE/PLUS/PRO/BUSINESS planı şirket erişimi sağlamaz veya aktif şirket
erişimini kaldırmaz. CANCELLED ve BILLING_ISSUE durumları geçerli dönem/grace
süresince erişebilir; `autoRenewing=false` tek başına expiry değildir.

Aynı `BusinessBillingPolicy` kararı HTTP workspace interceptor'ında ve doğrudan
servis erişiminde uygulanır. `/auth/me` üyelikle birlikte erişimsiz durumu 200
olarak açıklarken, izinsiz BUSINESS isteği 403 kalır. PERSONAL erişimi devam eder.
`SubscriptionService` kendi planını zaten tarih/izin üzerinden hesaplıyordu;
`WorkspaceResolver` istek hesabını zaten sabitliyordu. Bu kontroller kaldırılmadı.

## Flutter davranışı ve yarış kontrolleri

- Üyelik ile `businessAvailable` ayrı tutulur. ID/rol, kişisel plan veya eski
  navigation verisi Business yetkisi yerine geçmez.
- Süresi dolmuş şirkette üyelik ve adı görünür kalır; Business seçeneği kapalıdır
  ve neden açıklanır. Şirket yönetimi işlemi erişim yokken etkin gösterilmez.
- Auth response, uygulama başlangıcı, yeniden giriş ve normal profil yenilemesi
  yalnız açık sunucu erişim kararıyla Business seçimini açabilir. Eski backend
  yeni alanları göndermiyorsa istemci güvenli biçimde PERSONAL kullanır.
- 403 WORKSPACE_UNAVAILABLE sonrasında üyelik saklanır; seçim PERSONAL olur ve
  kullanılabilirlik kapanır. Yalnız BUSINESS kapsamlı böyle bir hata bu durumu
  değiştirebilir; normal 403 ve geçici ağ/503 hatası üyelik/erişimi iptal etmez.
- Workspace/session generation kontrolü korunur; revoke ve açık seçim bekleyen
  preference initialization işlemini de geçersiz kılar. Profil isteklerinin
  sırası ayrıca takip edilir: daha önce başlayan yanıt, son profili ezemez.
- MainShell, eski şirket oluşturma route sonucundan veya navigation parametresinden
  Business izni kurmaz. Oturum tercihini yükleme başka güncel işlemle çakışırsa
  bunu login süresi dolması olarak yorumlamaz.
- Abonelik yenilendiğinde yeni profil aynı şirketi tekrar erişilebilir gösterir.
  Kullanıcının PERSONAL seçimi korunur; Business'a geçişte `/workspace` yine
  sunucudan doğrulanır. Yeni şirket veya ikinci ödeme gerekmez.
- Yeni RevenueCat sync, polling, yeniden deneme döngüsü veya ek profil çağrısı
  eklenmedi. Profil erişimi mevcut yerel DB kayıtlarından tek owner/billing
  sorgusuyla hesaplanır. Desteklenmeyen platformlarda native RevenueCat kimlik
  kuyruğuna girilmeden mağazanın kullanılamadığı bildirilir.

## Değişen dosyalar

| Alan | Dosyalar |
| --- | --- |
| Backend erişim kararı | `BusinessBillingPolicy.java`, yeni `BusinessWorkspaceAccess.java`, `BusinessContextService.java` |
| Üyelik API yanıtı | `BusinessAccountResponse.java`, `AuthService.java`, `BusinessAccountService.java` |
| Flutter profil/oturum | `business_account.dart`, auth `auth_service.dart`, `workspace_session.dart`, `api_client.dart` |
| Workspace UI ve navigation | `workspace_service.dart`, `workspace_switcher.dart`, `business_workspace_access.dart`, `main_shell.dart`, `profile_screen.dart`, `subscription_screen.dart` |
| Mağaza platform kontrolü | `revenue_cat_gateway.dart` |
| Backend regresyonları | `WorkspaceHttpTest`, `CreditWalletPersistenceTest`, `InspectionPersistenceTest`, `BusinessSubscriptionFlowTest`, `BusinessAccountServiceTest` |
| Yeni Flutter regresyonları | `workspace_access_test.dart`, `workspace_expiry_navigation_test.dart` |
| Mevcut Flutter fixture'ları | Workspace session/shell/billing race, Business subscription flow ve Profile testleri |

## Testler

Yeni HTTP regresyonları OWNER ve MEMBER için ardışık profil 200, erişim alanları,
BUSINESS 403 ve PERSONAL 200 zincirini doğrular. Gerçek yerel PostgreSQL testleri
production ve sandbox için expiry, yenileme, refund, dönem devam eden iptal,
izin kaldırılması ve üyelik/kişisel araç/kredi izolasyonunu çalıştırır. Sahipsiz
şirketin verisi silinmez; geçerli owner olmadan erişim açılmaz.

Flutter testleri Profil → Krediler ve Paketler → geri akışını iki rol için üçer
kez çalıştırır; Business seçeneği kapalı kalır. Mağazasız navigation fixture'ında
`/workspace` denemesi veya `/billing/sync` döngüsü oluşmaz. Yeniden giriş/başlangıç, eski profil yanıtının
403'ten sonra gelmesi, yenilenmiş aktif profili eski expiry yanıtının ezmemesi,
geçici ağ hatası ve navigation cache senaryoları ayrıca doğrulanır.

| Doğrulama | Sonuç |
| --- | --- |
| Maven tüm `*Test,*IT`, üç opt-in PostgreSQL DB etkin | 371 toplam; 369 başarılı, 0 hata, 2 atlandı |
| Gerçek PostgreSQL cüzdan/politika testleri | 33/33 başarılı |
| Gerçek JPA persistence testleri | 18/18 başarılı |
| Flutter tüm testler | 296/296 başarılı |
| Flutter analyze | Sorun yok |
| Değişen Dart kaynak/testlerinde format | Değişiklik yok, başarılı |
| `git diff --check` | Başarılı |

Atlananlar mevcut `AiAssistantBusinessConcurrencyIT` ve
`AiAssistantServiceConcurrencyIT`; Docker bulunamadığı için kendi
`disabledWithoutDocker` koşullarıyla atlandılar. SQL/JPA ve yeni expiry
regresyonları atlanmadı. Yeni testler gerçek mağaza ödemesi yapmaz.

Backend doğrulama komutu (PowerShell):

```powershell
.\mvnw.cmd -B '-Dtest=*Test,*IT' `
  '-Dcredit.test.jdbc-url=jdbc:postgresql://127.0.0.1:55440/credit_system_test' `
  '-Dcredit.test.username=report_test' `
  '-Dinspection.test.jdbc-url=jdbc:postgresql://127.0.0.1:55440/vehicle_inspector_test' `
  '-Dinspection.test.username=report_test' `
  '-Dsecurity.test.jdbc-url=jdbc:postgresql://127.0.0.1:55440/security_audit_test' `
  '-Dsecurity.test.username=report_test' test
```

Mobil: `flutter test --no-pub --timeout 60s` ve `flutter analyze --no-pub`.
Yerel loglar `target/workspace-expiry-backend-full.log`,
`target/workspace-expiry-flutter-full.log`, `target/workspace-expiry-flutter-analyze.log`
altındadır ve commitlenmez. Başlatılan test PostgreSQL süreci testlerden sonra
durduruldu. Üç opt-in test DB'si yalnız `127.0.0.1:55440` üzerindeki
`credit_system_test`, `vehicle_inspector_test`, `security_audit_test` isimli
disposable veritabanlarıdır. Production DB veya abonelik kayıtları değiştirilmedi.

## Yayın ve geri dönüş

1. CI ve bu dal incelendikten sonra açık onayla backend'i önce yayınlayın.
   DB migration veya yeni Railway değişkeni gerekmez. Bu düzeltme mevcut kayıtları
   yeniden yazmaz, üyelik/araç/davet/kredi silmez, RevenueCat ayarını değiştirmez.
2. Yeni Flutter sürümünü ardından yayınlayın. Mağazadaki son build numarasına göre
   yeni numara kullanılmalı; dalın başlangıcındaki `pubspec.yaml` `1.0.0+51`.
   Backend güncellenmeden yeni mobil sürümde Business erişimi güvenli olarak kapalı
   görünür. Eski mobil sürüm yeni alanları kullanmadığından UI döngüsünün bitmesi
   için mobil güncelleme de gereklidir.
3. Aktif owner/member, süresi bitmiş owner/member ve yenilenmiş aynı şirkette cihaz
   kontrolü yapın. Süresi bitmiş üyelik `/auth/me` içinde false olarak kalmalı;
   PERSONAL → Krediler → geri tekrarlarında BUSINESS `/workspace` çağrısı olmamalı.
   Dönemi devam eden iptalde erişim açık olmalı. Bir üyenin kendi planını yükseltmek
   owner süresi dolmuş şirketi açmamalı.
4. Sorunda veri düzeltme SQL'i çalıştırmayın veya üyelikleri silmeyin. Önceki mobil
   sürüme dönmek eski UI döngüsünü geri getirebilir. Yeni istemciler kullanılırken
   backend erişim alanlarını ve güvenlik kontrolünü koruyan bir düzeltme tercih edin;
   eski backend'e dönüşte yeni istemciler bilinmeyen erişimi kapalı gösterir.
   Önceki sandbox izolasyonu için
   [production Business yayın planındaki](PRODUCTION_BUSINESS_SANDBOX.md) geri dönüş
   kısıtları da geçerlidir.

Bu çalışma yalnız feature branch'i yayınlar. Master merge, Railway deployment,
production DB müdahalesi ve environment variable değişikliği yapılmaz.
