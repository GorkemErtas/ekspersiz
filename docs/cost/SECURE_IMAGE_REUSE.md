# Oturum içinde güvenli fotoğraf yeniden kullanımı

17 Ekim 2026. Taban: güncel `origin/master` / `0ef5cee`. Çalışma dalı:
`feature/secure-session-image-reuse`. Yeni paket, backend değişikliği veya altyapı
eklenmedi; master'a merge ve Railway deploy yapılmadı.

## Doğrulanan neden ve korunan akış

`InspectionResultScreen.initState` her açılışta fotoğraf GET'i başlatıyordu.
`InspectionService.getInspectionImage` doğrudan `ApiClient.getBytes` çağırıyordu;
istek paylaşımı veya ekranlar arasında yeniden kullanım yoktu. Sonuç ekranı ayrıca
her görüntü oluşturulurken `Uint8List.fromList` ile kopya üretiyordu ve decode boyutu
sınırlanmıyordu.

Yükleme ekranında zaten `Uint8List` bulunuyor. Mevcut akış korunuyor:
tek fotoğraf yükleme → kalite doğrulama → FRONT/REAR analizi → sonuç ekranı.
Baytlar navigasyon parametresi olarak taşınmıyor; `AnalyzingScreen` ve yükleme
ekranının üretim kodunda değişiklik gerekmiyor. Başarılı yükleme yanıtından sonra
aynı byte nesnesi sınırlara uygunsa geçici görüntü katmanına kaydediliyor.
Yanlış inspection ID, eksik path, başarısız yükleme ve decode edilemeyen veri
yeniden kullanım kaydı oluşturmuyor. Preview kontrolü upload/analiz sonucunu değiştirmiyor.

Backend incelemesinde JSON ve fotoğraf endpoint'lerinin ikisinin de
`InspectionAccessService.requireInspection` ile güncel kişisel sahiplik/işletme
üyeliği doğruladığı görüldü. `FileStorageService` orijinal JPEG/PNG/WEBP baytlarını
benzersiz dosya adına kaydediyor. Analizi başlayan incelemenin fotoğrafının
değiştirilmesi backend'de zaten yasak. Bu kontroller korunuyor.

## Uygulama mimarisi ve güvenlik

`InspectionService`, varsayılan olarak tek bir `InspectionImageCache` kullanıyor;
testlerde ayrı örnek enjekte edilebiliyor. Anahtar: kullanıcıya bağlı opak oturum/
yetki kapsamı nesnesi + inspection ID + sunucudan doğrulanan güncel imagePath.
JWT, e-posta, ad ve açık kullanıcı kimliği cache anahtarına veya loga eklenmiyor.
Profilde kullanıcı/işletme/rol değişimi kapsam nesnesini yeniliyor.

Her okuma, RAM hit dahil, `/inspections/{id}` JSON isteğiyle yeniden yetkilendiriliyor.
Çevrimdışı durumda veya 401/403/404/timeout durumunda eski görüntü döndürülmüyor.
İlk fotoğraf GET'i sonrasında path tekrar doğrulanıyor; indirme sırasında değişen
fotoğraf eski anahtar altında saklanmıyor. Aynı inspection için eşzamanlı çağrılar
yetkilendirme ve indirme future'ını paylaşıyor. Açık tekrar deneme kaydı ve eski
isteğin geçerliliğini iptal ediyor.

Inspection'a özel invalidasyonun bildirimi yalnızca o inspection'ın açık sonuç
ekranını temizliyor; diğer görüntüler ve devam eden indirmeleri korunuyor. Global
oturum/yetki invalidasyonu bütün sonuç ekranlarını temizlemeye devam ediyor.

Token yazma/silme/clearAll başlangıcında bellek senkron temizleniyor. Başarılı yeni
login de yeni kapsam açıyor. Logout, hesap silme, 401 ve bilinen işletme/üyelik
değişimlerinde eski kapsam kullanılamıyor. 403 fotoğrafları temizliyor fakat tokenı
silmiyor; mevcut auth davranışı korunuyor. Bekleyen indirme/yükleme tamamlandığında
oturum ve bellek jenerasyonu tekrar kontrol ediliyor; eski sonuç cache'e yazılmıyor.

Sunucunun `Cache-Control: no-store` başlığı aynı kalıyor. Bu katman HTTP/proxy cache
kurmuyor; uygulamanın açıkça yönettiği geçici preview baytlarını RAM'de tutuyor.
Kalıcı fotoğraf cache'i ve offline görüntüleme eklenmiyor. Mevcut picker geçici
dosyaları ve kullanıcı isteğiyle oluşturulan PDF dosyalarının davranışı değişmiyor.

## Bellek ve decode

- En fazla **12 MiB**, **3 kayıt**, kayıt başına **8 MiB**, eklenmeden itibaren
  **5 dakika TTL**; hit TTL'yi uzatmıyor. LRU eviction uygulanıyor. Süresi geçen
  kayıtlar sonraki cache erişimi/yazımında temizleniyor.
- Sınır üstü yükleme seed edilmiyor; normal fotoğraf GET'iyle görüntülenebiliyor.
  Sınır üstü indirme sonucu ekranda kullanılabiliyor fakat yeniden tutulmuyor.
- Boş/bozuk dosya için bir piksellik geçici codec frame'i doğrulanıp dispose ediliyor;
  doğrulama global Flutter ImageCache'e bitmap eklemiyor.
- Ekran fiziksel piksel genişliğine göre `ResizeImagePolicy.fit` kullanıyor;
  üst sınır **1600 × 1000**. `BoxFit.contain`, oran ve orijinal baytlar korunuyor.
  Bu boyut tek RGBA frame için teorik yaklaşık 6,1 MiB'dir; cihaz RAM ölçümü değildir.
- Bellek baskısı ve uygulamanın arka plana geçmesi RAM cache'ini temizliyor.
  Sonuç ekranındaki future ve görüntü widget'ı da bırakılıyor. Kapatılan/değişen
  görüntünün Flutter ImageCache anahtarı ayrıca evict ediliyor. Resume sunucudan
  yeniden yetkilendiriyor. Bellek/arka plan temizliği hata olarak gösterilmiyor;
  nötr yer tutucu ve “Fotoğrafı Yeniden Yükle” düğmesi sunuluyor. Bellek baskısında
  hemen otomatik indirme başlatılmıyor. Gerçek yükleme hatalarında hata kartı korunuyor.
- Limit yalnızca tutulan encoded cache baytlarının bütçesidir. Aktif ekran,
  in-flight HTTP gövdeleri, upload/picker, codec/native/GPU ve PDF belleği toplamına
  12 MiB garantisi verilmez. İşletim sisteminde anında fiziksel sıfırlama iddiası yoktur.

## Ağ davranışı

| Durum | Önce fotoğraf GET'i | Şimdi fotoğraf GET'i | Yeni JSON kontrolü |
| --- | ---: | ---: | --- |
| Aynı değişmemiş fotoğrafı iki kez açma | 2 | 1 | Soğuk indirmede önce/sonra, hit'te bir kez |
| Eşzamanlı iki okuma | 2 | 1 | Paylaşılan işlem |
| Kabul edilen ve sınıra uyan yükleme sonrası ilk sonuç | 1 | 0 | Bir kez |
| Yeni imagePath / TTL aşımı / açık retry | Her okumada 1 | Yeni indirme 1 | Önce/sonra |

Fotoğraf GET sayıları mock HTTP/servis testlerinde doğrulandı; önceki sayılar
eski doğrudan çağrı akışından belirlendi. JSON kontrolleri ek gecikme ve trafik
oluşturur. Üretim egress baytı, p95 gecikme, gerçek cihaz RAM'i veya fatura kazancı
ölçülmedi; yüzde maliyet/hızlanma iddiası yoktur.

## Değiştirilen dosyalar

- `mobile/lib/core/auth/session_manager.dart`: opak kapsam ve kullanıcı/işletme/rol invalidasyonu.
- `mobile/lib/core/storage/token_storage.dart`: merkezi token yaşam döngüsü temizliği.
- `mobile/lib/core/network/api_client.dart`: 403'te görüntü invalidasyonu.
- `mobile/lib/features/auth/services/auth_service.dart`: güncel profil kapsamını izleme.
- `mobile/lib/features/business/services/business_service.dart`: bilinen üyelik değişimlerinde temizlik.
- `mobile/lib/features/inspection/services/inspection_image_cache.dart`: sınırlı RAM, LRU/TTL, single-flight ve stale-completion koruması.
- `mobile/lib/features/inspection/services/inspection_service.dart`: yetkilendirilmiş okuma ve başarılı upload seed'i.
- `mobile/lib/features/inspection/screens/inspection_result_screen.dart`: kopyasız, sınırlı decode ve ekran/cache yaşam döngüsü.
- `mobile/test/features/inspection/services/inspection_image_cache_test.dart`: sınırlar, yarışlar, hata ve upload testleri.
- `mobile/test/features/inspection/services/inspection_image_session_test.dart`: gerçek ApiClient/TokenStorage üzerinden auth ve timeout testleri.
- `mobile/test/features/inspection/screens/inspection_result_screen_test.dart`: decode sınırı ve görüntü temizliği.
- `mobile/test/features/inspection/screens/single_photo_flow_test.dart`: upload → sonuç ve geçmişten tekrar açma.
- `mobile/test/features/responsive_screens_test.dart`, `mobile/test/support/ui_mock_api.dart`: mevcut mock'ların yetki kontrolüne ve gerçek async codec'e uyarlanması.
- Bu rapor.

## Doğrulama ve kalan sınırlar

Son doğrulama (`mobile` dizininde): `flutter analyze --no-pub` **0 sorun**;
`flutter test --no-pub` **106 geçti, 0 başarısız**; `git diff --check` **temiz**.
Son regresyon testleri aynı anda açık farklı sonuç ekranlarının yerel invalidasyonda
korunmasını, diğer inspection'ın single-flight indirmesinin sürmesini, bellek ve
arka plan temizliğinde nötr yer tutucuyu, manuel reload/resume yetkilendirmesini ve
gerçek reload hatasının hata kartını göstermesini de kapsıyor.
Hedefli testler yeniden açma, single-flight, aynı orijinal nesnenin yeniden kullanımı,
fotoğraf değiştirme/silme, oturum değişimi, eski indirme/yükleme completion'ları,
401/403/404, gerçek HTTP timeout ve bağlantı hatası, bozuk/boş gövde, TTL/LRU,
toplam bellek, büyük dosya fallback'i ve bellek baskısını kapsıyor. Kamera/galeri,
FRONT/REAR, kalite reddi, analiz retry, rapor UI, geçmiş navigasyonu, dar/geniş ekran,
tema, profil, işletme ve abonelik regresyon testleri de korunuyor.

Backend/AI/şema ve PDF üretim iş kuralları değiştirilmedi; backend testleri bu
çalışmada çalıştırılmadı. Her iki PDF servisi de aynı `getInspectionImage` metodundan
orijinal baytları almaya devam ediyor; küçültülmüş preview PDF'e veya modele gitmiyor.
Native paylaşım, gerçek Android/iOS kamera, EXIF yönleri ve üretim Railway uçtan
uca testi yapılmadı. Google login token kaydı aynı merkezi hook'u kullanıyor;
Google sağlayıcısına gerçek giriş testi yapılmadı.

Uzaktaki yetki değişimi açık ekrana sunucu bildirimi olmadan anında ulaşmaz; sonraki
görüntü okumasında ve resume'da kontrol edilir. Sunucunun benzersiz path altındaki
dosyayı dışarıdan aynı isimle değiştirmediği varsayılır; uygulamanın normal upload
akışı yeni path üretir. TTL tamamlanmış ekranı kapatmaz; sonraki reuse'u sınırlar.

Thumbnail altyapısı ihtiyacı şu an ölçümle kanıtlanmış değil. Büyük dosya fallback
sıklığı, gerçek cihaz decode/RAM ve üretim egress/latency ölçümleri sonrasında
değerlendirilmeli; bu değişiklik için yeni thumbnail servisi gerekmiyor.
