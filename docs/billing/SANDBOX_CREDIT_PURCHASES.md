# Yetkili sandbox kredi testleri — 23 Ekim 2026

## Kök neden ve akış

`dd84edfb1cceda6ca71c83b1645564be0a435e65` (21 Ekim) güvenlik commit'i,
`BILLING_ALLOW_SANDBOX=false` varsayılanıyla sandbox webhook'larından kayıt
oluşturmadan dönüyor, customer sync içindeki sandbox alımlarını da atlıyordu.
Dolayısıyla webhook yetkilendirmesi doğru ve `/billing/sync` ile `/credits`
yanıtları 200 olsa bile kredi verilmemesi beklenen kod davranışıydı.

Mevcut akış korunur:

1. Flutter `/billing` yanıtındaki sunucu üretimi `billingCustomerId` ile RevenueCat'e bağlanır.
2. `/credits/purchase-intents/{productId}` kullanıcı/ürün/hedef hesap bağını kaydeder.
3. Play satın alımı RevenueCat SDK üzerinden tamamlanır; Flutter store transaction ID'yi alır.
4. Yetkilendirilmiş webhook veya sunucunun secret API key ile yaptığı
   `GET /subscribers/{billingCustomerId}` sorgusu alımı doğrular.
5. Backend izin, ortam, katalog, önceki işlem ve satın alma niyeti kontrollerini
   uygular. PostgreSQL işlem kilidi altında cüzdanı ve işlem kaydını atomik yazar.
6. Flutter sync sonrasında `/credits/purchases/{transaction}` onayını bekler.
   200 yanıtı veya SDK başarısı tek başına yerel kredi üretmez; `/credits`
   sunucunun bakiyesini gösterir. Ekran yeniden açıldığında sync tekrar çalışır.

## Yetki sınırı

- `BILLING_SANDBOX_CUSTOMER_IDS`: sunucudaki `users.billing_customer_id` alanından
  alınan, virgülle ayrılmış canonical UUID izin listesi. Varsayılan boştur.
  Boş liste hiçbir yeni sandbox kredi alımını kabul etmez. Geçersiz UUID
  yapılandırma hatasıdır; joker değer desteklenmez.
- E-posta, Play lisans test listesi, istemci bayrağı, RevenueCat subscriber
  attribute ve alias listesi bu yetkiyi vermez. Exact backend müşteri kimliği
  eşleşmelidir; izin hem billing hem cüzdan servisinde denetlenir.
- İstisna **kişisel katalog kredileri** (analiz/asistan/slot) içindir.
  Sandbox şirket kredileri ve sandbox abonelikler, izinli kullanıcı için de
  kapalıdır. Böylece normal şirket üyeleri ortak havuz üzerinden ücretsiz
  sandbox kredisine veya Business hakkına erişemez. Gerçek Business ve şirket
  satın alımları mevcut kurallarıyla çalışır. Sandbox Business/şirket testi
  gerekiyorsa ayrı ve izole bir tasarım gerekir; bu yama onu etkinleştirmez.
- Eski `BILLING_ALLOW_SANDBOX` artık okunmaz; `true` yapmak genel geçiş sağlamaz.
- Listeden çıkarma yeni sandbox teslimlerini durdurur. Önceden teslim edilmiş
  bakiyeler topluca silinmez; gerçek alımlarla karışmış bakiyeye müdahale edilmez.
  Bu nedenle normal kullanıcı hesabını geçici olarak test hesabı yapmayın;
  ayrı test hesapları kullanın. Doğrulanmış sandbox iadeleri yetki kaldırıldıktan
  veya hesap silindikten sonra da sadece sandbox işlem kaydına uygulanır.

## Kayıtlar, tekrar teslim ve migration

V16 `credit_purchases` ve `billing_webhook_events` tablolarına `environment`
ekler. Yeni kayıtlar `SANDBOX` / `PRODUCTION`; satın alım içermeyen TEST/TRANSFER
olayları gerekirse `CONTROL` olarak tutulur. Tekillik ortam + işlem/olay ID'dir.
`credit_events` satın alma/iade anahtarları ortamı da taşır. Farklı müşterilere
restore veya eşzamanlı webhook/sync aynı ortamda ikinci hak üretmez.

V16 öncesi kayıtlar `LEGACY` olarak kalır: o şemada ortam tutulmadığından
geriye dönük üretim/test etiketi uydurulmaz. Hiçbir cüzdan bakiyesi, dönem,
borç veya rezervasyon yeniden hesaplanmaz. LEGACY işlem ID'leri yeniden
kredilendirmeyi engeller; sandbox iadeleri LEGACY kayıtlara dokunmaz.
Mevcut üretim iade yolu LEGACY alımları işleyebilir.

Eski, **zaten kredilendirilmiş** bir sandbox alımının iadesi gerekiyorsa,
operatör önce RevenueCat/Play üzerinden transaction ID, ürün, müşteri ve ortamı
doğrulayıp yalnız o LEGACY işlem kaydını kontrollü olarak sınıflandırmalıdır.
Toplu ortam etiketleme veya bakiye güncelleme yapılmamalıdır. Bu belirsizlik
yalnız eski kayıtlara aittir; yeni sandbox iadeleri otomatik çalışır.

İade önce gelirse ortama özel tombstone tutulur. İade sonrası geç teslim veya
restore tekrar kredi vermez. Harcanmış kredi iadesi mevcut borç mekanizmasını
kullanır. Sandbox iadesi aynı ID'li production alımını değiştirmez.

Eksik/bilinmeyen webhook ortamı veya REST yanıtında boolean olmayan/eksik
`is_sandbox` alanı üretim kabul edilmez. Webhook authorization ve varsa imza,
ürün kataloğu, satın alma niyeti, transaction sahipliği ve kredi kilitleri korunur.
İstemcinin gönderdiği bir transaction ID yalnızca sorgu yapar; kayıt oluşturamaz.

## Railway ve RevenueCat ayarları

1. Veritabanı yedeğini alın. Backend'i V16 ile birlikte yayınlayın; aynı veritabanına
   eski backend yazıcılarını paralel çalıştırmayın. Bu branch henüz yayınlanmış değildir.
2. Yetkilendireceğiniz ayrı Ekspersiz test hesabının UUID'sini backend verisinden
   bulun; RevenueCat App User ID ile aynı olmasını kontrol edin. Örnek salt okunur sorgu:

   ```sql
   SELECT id, email, billing_customer_id
   FROM users WHERE email = 'test-hesabiniz@example.com';
   ```

3. Railway **backend service Variables** içine
   `BILLING_SANDBOX_CUSTOMER_IDS=<uuid1>,<uuid2>` ekleyip yeniden deploy edin.
   Değeri Flutter build değişkenine koymayın. `BILLING_ALLOW_SANDBOX=false`
   kalabilir veya eski değişken silinebilir; artık etkisizdir.
4. `REVENUECAT_SECRET_API_KEY`, `REVENUECAT_WEBHOOK_AUTHORIZATION` ve varsa
   `REVENUECAT_WEBHOOK_SIGNING_SECRET` mevcut doğrulanmış değerleriyle kalır.
   Mobile yalnız public SDK anahtarı kullanır; bu düzeltme için yeni uygulama
   sürümü veya test kullanıcısı bayrağı gerekmez.
5. RevenueCat webhook entegrasyonunda doğru uygulama ve mevcut HTTPS endpoint
   (`/api/v1/billing/revenuecat/webhook`) seçili olsun. **Sandbox ve production**
   olayları gönderilsin. `NON_RENEWING_PURCHASE` ve `CANCELLATION` filtre dışında
   kalmasın; mevcut abonelik olayları da korunmalı. Authorization mevcut backend
   değeriyle aynı kalmalı. [RevenueCat webhook yapılandırması](https://www.revenuecat.com/docs/integrations/webhooks).
6. `eksper_analysis_5` dahil mağaza ürünleri/`credits_v1` offering ve Play lisans
   test kullanıcısı kurulumu mevcut şekilde kalır. Restore davranışı **Keep with
   original App User ID** olmalı; iade bildirimi için Play → RevenueCat bağlantısı
   çalışmalı. [Restore davranışı](https://www.revenuecat.com/docs/projects/restore-behavior).

## Önceden atlanmış alımları uzlaştırma

İzinli test hesabıyla Krediler ve Paketler ekranını açın veya o hesaba ait JWT
ile `POST /api/v1/billing/sync` çağırın. Backend RevenueCat'ten aldığı doğrulanmış
geçmiş `non_subscriptions` kayıtlarını yeniden değerlendirir; yeniden satın alma
veya elle kredi ekleme gerekmez. Aynı sync'i tekrarlamak krediyi çoğaltmaz.

Orijinal satın alma zamanı, saklanmış satın alma niyetinin 30 günlük penceresine
düşmelidir. **Bugünün** pencere dışında olması sorun değildir; 40 gün sonra sync
ile kurtarma entegrasyon testinde doğrulanır. Niyet kaydı hiç yoksa veya satın
alma zamanı pencere dışındaysa otomatik kredi verilmez. Sonradan yeni niyet
oluşturmak eski alımı yetkilendirmez; doğrulanmış operatör incelemesi gerekir.

RevenueCat REST cevabında görünmeyen eski bir alım için doğru müşteri, store
transaction ID, ortam ve refund durumunu inceleyin; gerektiğinde RevenueCat'in
doğrulanmış orijinal webhook'unu yeniden gönderin. Sahte webhook veya SQL ile
kredi üretmeyin. Önceden iade edilmiş işlem tekrar alım olarak oynatılmamalıdır.

Salt okunur teslim denetimi:

```sql
SELECT transaction_id, environment, customer_id, product_id, account_id, quantity, refunded
FROM credit_purchases WHERE customer_id = '<test-billing-customer-id>'
ORDER BY created_at DESC;
```

İzin verilmeden atlanan satın alma webhook'ları işlenmiş olarak kaydedilmez;
sonradan yetki verildiğinde tekrar teslim edilebilir. İadeler tekrar teslimi
engelleyen kayıt bırakır. HTTP 200'ü teslim kanıtı olarak kullanmayın.

## Doğrulama

23 Ekim 2026 sonuçları:

| Kontrol | Sonuç |
|---|---|
| Maven `*Test,*IT`, kredi/inceleme/güvenlik PostgreSQL testleri etkin | 290 test: 288 başarılı, 0 hata, 2 atlandı |
| `CreditWalletPersistenceTest` (yukarıdaki toplamın içinde) | 19/19 başarılı; V1–V16 ve bakiye koruma, ortam çakışması, eşzamanlılık, harcama/iade, 40 gün sonra uzlaştırma |
| `BillingServiceTest` / `RevenueCatClientTest` / webhook verifier (toplamın içinde) | 16 + 2 + 3 başarılı |
| `flutter test --no-pub --reporter expanded` | 220/220 başarılı; 6 yeni servis regresyonu dahil |
| `flutter analyze --no-pub` | Sorun yok |
| Dart format / `git diff --check` | Başarılı |

Atlananlar `AiAssistantBusinessConcurrencyIT` ve `AiAssistantServiceConcurrencyIT`:
Docker bulunmadığı için Testcontainers koşulu devre dışı bıraktı. Ayrı yerel
PostgreSQL kredi eşzamanlılık testleri ise gerçekten çalıştı. PostgreSQL test
harness'i yerel pgvector eksikliği için vector alanını yalnız test şemasında
REAL[] olarak temsil eder; üretim migration dosyaları değiştirilmez.

Backend komutu (PowerShell, yalnız disposable test veritabanları):

```powershell
.\mvnw.cmd -B '-Dtest=*Test,*IT' `
  '-Dcredit.test.jdbc-url=jdbc:postgresql://127.0.0.1:55439/credit_system_test' `
  '-Dcredit.test.username=security_test' `
  '-Dinspection.test.jdbc-url=jdbc:postgresql://127.0.0.1:55439/vehicle_inspector_test' `
  '-Dinspection.test.username=security_test' `
  '-Dsecurity.test.jdbc-url=jdbc:postgresql://127.0.0.1:55439/security_audit_test' `
  '-Dsecurity.test.username=security_test' test
```

Yerel loglar (Git'e eklenmez): `target/sandbox-backend-full.log`,
`target/sandbox-flutter-tests.log`, `target/sandbox-flutter-analyze.log`.

Testler gerçek yerel PostgreSQL kullanır; RevenueCat ağ cevabı/SDK testte
kontrollü taklit edilir. Gerçek Play lisans alımı, canlı RevenueCat webhook'u
ve Railway deploy'u bu yerel testlerin kapsamı dışındadır.

Yayın sonrası cihaz kontrolü: izinli test hesabıyla 5 kredi alımı → 1 kredi
harcama → iade; iki sync ve aynı webhook tekrarı; izin listesinde olmayan
lisans test hesabında sıfır teslim; gerçek hesapta normal kredi/Business akışı.
Hesap değiştirme ve iade önce/geç satın alma sırasını da kontrol edin.
