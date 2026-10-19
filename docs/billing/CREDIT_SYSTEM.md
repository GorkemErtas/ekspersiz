# Kredi sistemi ve mağaza geçişi

## Fiyatlandırma

Referans para birimi TRY. Tek analiz 39,99 TL, tek asistan yanıtı 9,99 TL,
kalıcı ek araç slotu 4,99 TL. Kullanıcının son fiyat isteği, ilk taslaktaki
paket fiyatlarının yerine uygulanır: 5 adette %5, 10 adette %10, 20 adette %20.
50 adet için %25 kullanıldı; bu oran eski taslaktaki yaklaşık indirimi korur.
Fiyat önce toplam üzerinden hesaplanır ve kuruşa HALF_UP yuvarlanır.
Birim fiyatı, yuvarlanmış toplam / adet olarak gösterilir.

| Adet | İndirim | Analiz toplam | Analiz birim | Analiz tasarruf | Asistan toplam | Asistan birim | Asistan tasarruf |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 | %0 | 39,99 | 39,99 | 0,00 | 9,99 | 9,99 | 0,00 |
| 5 | %5 | 189,95 | 37,99 | 10,00 | 47,45 | 9,49 | 2,50 |
| 10 | %10 | 359,91 | 35,99 | 39,99 | 89,91 | 8,99 | 9,99 |
| 20 | %20 | 639,84 | 31,99 | 159,96 | 159,84 | 7,99 | 39,96 |
| 50 | %25 | 1.499,63 | 29,99 | 499,87 | 374,63 | 7,49 | 124,87 |

Business: **4.999,99 TL / ay**, şirket genelinde 10 aktif araç kapasitesi,
her gerçek abonelik döneminde 100 analiz + 200 asistan kredisi.
100 × 39,99 + 200 × 9,99 = 5.997,00 TL tekli kredi değeri;
Business farkı 997,01 TL (%16,63). Bu, **tekli alımlarla karşılaştırmadır**.
İndirimli 50'li paketlerle aynı kredi miktarı 4.497,78 TL olur; Business ayrıca
şirket yönetimini ve ortak araç kapasitesini içerir. En ucuz kredi paketi olduğu
iddia edilmez. Kalıcı slotların değeri her ay tekrar tasarruf olarak yazılmaz.

Backend fiyatları referanstır. Flutter tahsilat fiyatını RevenueCat StoreProduct
üzerinden alır. Tasarruf, aynı para birimindeki gerçek paket ve tekli ürün
fiyatlarından hesaplanır. Eksik/farklı para birimli ürünlerde tasarruf gösterilmez.
Mağazada olmayan ürünün referans fiyatı etiketlenir ve satın alma kapalıdır.

## Ürünler ve canlı mağaza ayarları

Merkezi katalog: `service/billing/CreditCatalog.java`.

| Tür | Kişisel ürün ID / RevenueCat package ID | Şirket ürün ID / package ID |
|---|---|---|
| Analiz | `eksper_analysis_{1,5,10,20,50}` | `eksper_analysis_{1,5,10,20,50}_business` |
| Asistan | `eksper_assistant_{1,5,10,20,50}` | `eksper_assistant_{1,5,10,20,50}_business` |
| Kalıcı slot | `eksper_slot_1` | `eksper_slot_1_business` |
| Business aboneliği | `eksper_business_monthly`, package `business_monthly` | Aynı mevcut ürün |

İlk üç satır toplam **22 tekrar satın alınabilir consumable** üründür. Google
Play Console'da TRY fiyatlarını yukarıdaki tabloya göre yapılandırın. RevenueCat
current offering içindeki custom package ID, consumable store product ID ile
aynı olmalıdır. Consumable ürünlere kalıcı subscription entitlement bağlamayın.
Business mevcut aylık ürününde kalır; onaylanan aylık fiyatı **4.999,99 TL** olarak Play Console'da yapılandırılmalıdır. Kodda ve belgelerdeki bu rakam mağazadaki mevcut fiyatı kendiliğinden değiştirmez.

### Google Play Console 2026 — yeni tek seferlik ürün oluşturma

1. Play Console > Ekspersiz > **Google Play ile para kazanın > Ürünler > Tek seferlik ürünler** > **Tek seferlik ürün oluştur**.
2. `Ürün kimliği` olarak tabloda yer alan **tam SKU** girilir (ör. `eksper_analysis_1`). Ad: `1 AI Hasar Analizi Kredisi`. Açıklama: `Ekspersiz'de 1 adet AI hasar analizi için kullanılabilen süresiz kredi.`
3. Vergi ve uygunluk bilgilerinin uygulamanın gerçek niteliğine göre yapılandırılması gerekir.
4. **Satın alma seçeneği** oluştururken örnek seçenek kimliği `buy`; satın alma türü **Satın alma (Buy)** olmalı, **Kiralama (Rent)** seçilmemeli. Tekli SKU zaten adet kadar kredi verir: "Miktarlar ve sınırlar" üzerinden ayrıca çoklu adet satışı açılmaz.
5. Bölge Türkiye, para birimi TRY; ürünün tablodaki ilgili **toplam fiyatı** girilir. Fiyatı ve bölgesel kullanılabilirliği gözden geçirip satın alma seçeneğini etkinleştirin.
6. RevenueCat ürün kataloğuna **store product ID** üzerinden içeri aktarın; current offering'e **custom package ID = aynı tam SKU** olacak şekilde ekleyin. Tüketilebilir paketlere subscription/lifetime entitlement bağlamayın.
7. Bütün SKU'lar hazır olsa bile gerçek kullanıcıların yeni satın alma ekranına ulaşabilmesi için backend V14, webhook ve mobil sürümün birlikte doğrulanması gerekir; ürünleri kurmak tek başına krediyi teslim etmez.

Yeni modelde **ürün kimliği**, **satın alma seçeneği kimliği** ve **RevenueCat package kimliği** ayrı kavramlardır; uygulamanın beklediği ilk ve üçüncü kimlik yukarıdaki SKU'dur.

Mevcut aboneler için mağazanın fiyat değişikliği/onay sürecini ayrıca yönetin.

RevenueCat custom App User ID backend'in kalıcı `billing_customer_id` UUID'sidir;
e-posta veya cihaz ID'si değildir. Restore davranışını **Keep with original App
User ID** olarak ayarlayın. Şirket alımlarının ayrı SKU'ları, kişisel/şirket hedefi
karışmasını önler. Satın alma öncesi backend 30 günlük hesap bağlama kaydı açar. Bu süre, Google Play'de beklemeye alınan ve daha sonra kesinleşen satın alımların hak kaybı olmadan eşleştirilmesi içindir.
Doğrulanmış satın alma zamanının bu pencereye düşmesi gerekir; pencere dışında
kalan/geçmiş niyeti bulunmayan alımlar otomatik kredi üretmez ve destek incelemesi
gerektirir. Bekleyen ödemenin kaç gün sonra tamamlandığını ve provider purchase
timestamp davranışını lisans test hesabıyla doğrulayın.

Sunucu ortamı: mevcut `REVENUECAT_SECRET_API_KEY`, `REVENUECAT_WEBHOOK_AUTHORIZATION`
ve varsa webhook imza ayarı. Mobil derlemede `REVENUECAT_ANDROID_PUBLIC_KEY`.
Secret anahtarları Flutter'a koymayın. Test ve üretim RevenueCat/Play ortamlarını
ayırın; kod mevcut sandbox abonelik desteğini korur.

Webhook `NON_RENEWING_PURCHASE` ve `CANCELLATION` kayıtları doğrulanmış exact
`app_user_id` için işlenir; alias listesindeki her hesaba kredi verilmez.
Global store transaction ID tektir. Reconciliation `store_transaction_id`
kullanır; RevenueCat'in dahili `id` alanını store transaction diye yorumlamaz.
Restore yeni hak üretmez. Refund önce gelse de tombstone tutulur. Harcanmış
kredinin iadesinde borç ayrı izlenir, kullanılabilir bakiye negatif gösterilmez.
İade/chargeback takibi için Play server notifications ve RevenueCat webhook
bağlantısını etkinleştirin. HTTP başarılı ama henüz doğrulanmamış ödeme için
uygulama başarı mesajı yerine bekleme mesajı gösterir; yeniden açılışta sync olur.

## Tüketim ve veri bütünlüğü

`credit_accounts` kişisel ve şirket hesaplarını ayırır. Her resource için
`credit_wallets` kalıcı, dönemlik ve iade borcu tutar. Şirket havuzunu OWNER ve
MEMBER birlikte kullanır; yalnızca aktif Business sahibi şirket adına alabilir.
Üyelikten ayrılmak kişinin kişisel bakiyesini değiştirmez.

`CreditWalletService` kısa transaction içinde hesap satırını kilitler. Aynı
kullanıcının eşzamanlı pahalı istekleri advisory lock + aktif rezervasyonla
sınırlanır. Kilit beklemesi 3 saniyedir; meşgul isteği kontrollü hata alır.
Araç kapasitesi doğrulaması, aracın insert edildiği transaction'a katılır.
AI/network çağrıları kredi transaction'ı dışında yürür.

Analiz: önce 1 kredi rezerve edilir, fotoğraf/ML ve detaylı rapor tamamlanınca
rapor erişimi ile tüketim aynı transaction'da kaydedilir. Teknik hata veya
uygunsuz fotoğraf krediyi iade eder. ML başarılı, rapor başarısızsa tekrar rapor
istenebilir; sadece başarılı tamamlanış ücretlenir. Önceden açılmış rapor tekrar
ücretlenmez. Asistan: request UUID + soru/araç/geçmiş hash'i, başarılı yanıtla
birlikte saklanır; aynı istek kayıtlı yanıtı döndürür. Kapsam dışı, açıklama
isteyen, yetersiz kanıtlı veya teknik hatalı yanıt rezervasyonu bırakır.

Rezervasyon 10 dakika geçerlidir. Her hesap işleminde süresi dolan rezervasyonlar
serbest bırakılır; cron veya Railway uyanıklığı gerekmez. Eski worker'ın geç
tamamlaması token ve rapor deneme kimliğiyle engellenir. Dönemlik iadeler sadece
aynı geçerli döneme döner. Dönem değişince yeni 100/200 bir defa tanımlanır;
kalan dönem kredileri devretmez. İptal, geçerli ödenmiş dönemi erken kapatmaz.
Business sona erince kalıcı şirket bakiyesi korunur ama şirket AI kullanımı ve
yeni şirket aracı ekleme aktif abonelik gerektirir.

## Başlangıç kredileri ve cihaz doğrulaması

E-posta girişi ve Google girişi aynı claim servisine ulaşır. Başlangıç kredileri
yalnızca Play Integrity doğrulandıktan sonra bir kez 1 analiz + 2 asistan olarak
verilir. Eksik yapılandırma, emülatör veya doğrulama kesintisinde ücretsiz hak
verilmez; giriş ve ücretli krediler kullanılabilir. Merkezde yeniden kontrol
aksiyonu vardır. Hata durumunda verilmemiş krediler verilmiş gibi gösterilmez.

Sunucu ayarları:

- `CREDIT_DEVICE_HMAC_KEY`: en az 32 karakterlik yüksek entropili kalıcı secret.
- `PLAY_INTEGRITY_PACKAGE`: varsayılan `com.gorkem.ekspersiz`.
- `PLAY_INTEGRITY_CERTIFICATE_SHA256`: Play App Signing sertifikasının base64url SHA-256 özeti.
- `PLAY_INTEGRITY_CLOUD_PROJECT_NUMBER`: Play uygulamasına bağlı Cloud project number.
- Railway için `PLAY_INTEGRITY_SERVICE_ACCOUNT_JSON_B64`: Play Integrity token decode yetkisi verilmiş servis hesabının JSON dosyasının **tek satırlık Base64** kodlanmış içeriği. Bu secret'ı yalnızca backend service variables içinde saklayın; Flutter'a, GitHub'a veya loglara koymayın. Alternatif olarak `GOOGLE_APPLICATION_CREDENTIALS` ile JSON dosya yolu veya desteklenen Google ADC iş yükü kimliği kullanılabilir. `FIREBASE_CREDENTIALS_JSON` değişkeninin varlığı bu entegrasyon için otomatik kimlik doğrulaması sağlamaz. Google Cloud projesinde API etkin, servis hesabı uygun yetkili ve Play Console bağlantısı tamamlanmış olmalıdır.

Native Android köprüsü Android ID'yi ve Standard Integrity token'ını sağlar.
Backend 3 dakikalık tek kullanımlık challenge, request hash, paket, imza,
`PLAY_RECOGNIZED`, `LICENSED`, `MEETS_DEVICE_INTEGRITY` ve zamanı denetler.
Ham cihaz ID'si/token saklanmaz; cihaz ve normalize hesap kimliği ayrı prefix'li
HMAC olarak tutulur. Claim device/account/identity benzersizlikleri PostgreSQL'de
atomiktir. Hesap silinince bu minimum tekrar kullanım kayıtları ve satın alma
tombstone'ları korunur; cached asistan yanıtı ve istek metadata'sı silinir.

**Mutlak fiziksel cihaz tekilliği garanti edilmez.** Android ID imza, kullanıcı
profili ve cihaz kapsamındadır; fabrika ayarı, farklı OS profili veya ele geçirilmiş
ortam sınırlardır. Integrity token, Android ID'nin donanımsal attestation'ı değildir;
request binding tek başına bu sınırı kaldırmaz. Device Recall erişimi projede
doğrulanamadığından kullanılmadı. Recall beta/erişim onayı alındığında eklenebilir.
İkinci el cihaz veya ortak cihaz daha önce hak kullanılmış görünebilir; otomatik
kimlik silme/reset yerine kayıt bazlı destek incelemesi yapılmalıdır. HMAC secret
rotasyonu önceki claim'leri geçersizleştirir: geçmiş anahtarlarla geçiş tasarlamadan
değiştirmeyin. Saklama süresi, açıklama metni ve KVKK dayanağı ürünün veri sorumlusu
tarafından belirlenmelidir; bu teknik uygulama hukuki uygunluk onayı değildir.

## Migration ve yayın sırası

Yeni `V14__credit_wallets.sql`, V1–V13 dosyalarını değiştirmez. Eski satın alınmış
analiz bakiyesini ve transaction ID'lerini taşır; restore ile yeniden kazanç
engellenir. Mevcut araçları silmez; kapasite fazlasını kalıcı ek slot olarak korur.
Aktif PLUS/PRO kullanıcılarının kalan analiz ve ücretli dönem asistan hakları
bir defa aktarılır. Geçerli eski planların mağaza yenilemeleri de ödenmiş süre
boyunca desteklenir; katalogdan yeni PLUS/PRO satışı kaldırılmıştır. Store Console
ve RC offering'de yeni satışları kapatın, mevcut abonelikleri kullanıcıdan habersiz
iptal etmeyin. Yönet/iptal bağlantısı uygulamada korunur.

Mevcut Business analizlerinin geçerli ay kullanımı düşülür. Eski asistan günlük
kayıtları geçmiş şirket sahipliği taşımadığından yeni ortak asistan havuzu geçişte
200 ile açılır; sonraki dönemler gerçek abonelik başlangıç kimliğiyle yenilenir.
Önceki FREE aylık haklar yeniden üretilmez; mevcut hesapların başlangıç hakkı da
aynı güvenli cihaz claim'inden bir kere değerlendirilir.

1. Veritabanı yedeği alın; migration'ı üretim kopyasında ve gerçek pgvector ile deneyin.
2. Play/RevenueCat ürünlerini, offering'i, refund notifications ve Integrity ayarlarını hazırlayın.
3. Backend + V14'ü yayınlayın. Migration sonrası eski backend yazıcısını çalıştırmayın:
   eski ve yeni ledger arasında çift yazım yoktur. Rollback sadece şema geri almak
   değildir; bu sırada gelen satın alma/tüketimleri uzlaştırmak gerekir.
4. Flutter build **40** ve üzerini yayınlayın; ardından `MINIMUM_ANDROID_BUILD=40`
   ayarlayın. Eski client kredi kontrolünü backend'de atlayamaz, fakat yeni fiyat ve
   hata akışı için yükseltme gerekir. Bu değişken dağıtım ortamında ayrıca ayarlanır.
5. Lisans test kullanıcısıyla iki kez aynı consumable, pending, iptal, refund,
   restore, hesap değişimi, iki çalışan eşzamanlı kullanım ve gerçek cihaz claim'ini deneyin.

## Yerel doğrulama

- `mvnw.cmd test`: backend unit/controller testleri.
- `mvnw.cmd test -Dcredit.test.jdbc-url=jdbc:postgresql://127.0.0.1:55439/credit_system_test`
  ayrı disposable PostgreSQL'de kredi migration/ledger/concurrency testlerini de çalıştırır.
  Varsayılan test kullanıcısı `credit_test`; şifre boş, yalnızca yerel test cluster'ı.
  Test kendi `credit_wallet_test` şemasını oluşturur ve kaldırır. V1–V14 uygulanır.
  Yerel Windows cluster'ında pgvector olmadığından sadece testte vector alanı
  REAL[] ile değiştirilir; üretim migration'ı değiştirilmez.
- `flutter test --no-pub`: 144 test; fiyat/tasarruf, eksik ürün, pending,
  kişisel/şirket görünümü, 320 px/2× metin ve dark/light dahil.
  Son şirket yönlendirmesi eklemesi sonrası satın alma ekranının 9 testi ayrıca geçti.
- `flutter analyze --no-pub` ve `flutter build apk --debug --no-pub`.

Canlı Play satın alımı, gerçek imzalı cihaz token'ı ve üretim migration'ı bu
çalışmada yürütülmedi. Mağaza fiyatları kod commit'i ile kendiliğinden değişmez.
Eski opt-in `InspectionPersistenceTest` ayrı `inspection.test.jdbc-url` gerektirir;
kredi testinin yerine geçmez ve bu doğrulama koşusunda etkinleştirilmedi.

## Sağlayıcı belgeleri

- [Play Integrity kurulumu](https://developer.android.com/google/play/integrity/setup)
- [Standard requests](https://developer.android.com/google/play/integrity/standard)
- [Device Recall](https://developer.android.com/google/play/integrity/device-recall)
- [RevenueCat customer API](https://www.revenuecat.com/docs/api-v1/customers)
- [RevenueCat non-subscriptions](https://www.revenuecat.com/docs/platform-resources/non-subscriptions)
- [RevenueCat restore davranışı](https://www.revenuecat.com/docs/projects/restore-behavior)
