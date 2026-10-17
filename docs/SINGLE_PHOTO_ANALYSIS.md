# Tek fotoğraflı hasar analizi

Geliştirme branch'i: `feature/single-photo-damage-analysis`. Başlangıç: güncel `master` (`374c54d`). Bu değişiklik üretime deploy veya master'a merge içermez.

## Yeni akış

1. Kamera veya galeriden **bir** hasar fotoğrafı seçilir. Hasar ayrıntıları ve çevresindeki araç parçası aynı karede net görünmelidir. Aracın tamamı istenmez; aşırı yakın/uzak çekimlerden kaçınma yönlendirmesi gösterilir.
2. Aynı ekranda **Ön yarı / Arka yarı** seçilir. Fotoğraf varken seçim yapılmadan analiz butonu etkinleşmez; gönderme metodu da seçimi doğrular.
3. Tek dosya `/inspections/{id}/image` üzerinden yüklenir. `/image-quality` mevcut `purpose=damage` doğrulamasını kullanır. Başarısız kalite kontrolünde önizleme korunur ve fotoğraf değiştirme imkânı sürer.
4. Mobil, `POST /inspections/{id}/analyze?vehicleRegion=FRONT|REAR` çağırır. **`requireContext=true` göndermez.** İkinci fotoğraf yükleme/doğrulama çağrısı yoktur.
5. Backend FastAPI'ye yalnızca `image` ve `vehicle_region` multipart alanlarını iletir. Kaydın eski bir context fotoğrafına sahip olması bu isteği çift fotoğraflı analize dönüştürmez.
6. Mevcut sonuç ve rapor ekranı açılır. Teknik hata durumunda yeniden deneme aynı fotoğrafı ve seçimi kullanır; yeniden ikinci dosya yüklemez.

## Dosya bazında değişiklikler

| Dosya | Değişiklik |
| --- | --- |
| `mobile/lib/features/inspection/screens/upload_damage_image_screen.dart` | İkinci adım, sayaçlar, geri dönüş ve ikinci fotoğraf durumu kaldırıldı. Ön/arka seçimi tek ekrana taşındı. Kalite, önizleme, fotoğraf değiştirme ve yükleme kilidi korundu. ImagePicker varsayılan davranışı aynı; widget testleri için isteğe bağlı picker verilebiliyor. |
| `mobile/lib/features/inspection/services/inspection_service.dart` | Kullanılmayan context yükleme/doğrulama metotları kaldırıldı. Tek fotoğraflı analyze isteğinde yalnızca bölge query parametresi gönderiliyor. |
| `src/main/java/com/gorkem/vehicle_inspector/service/DamageInspectionService.java` | Context doğrulama ve taşıma yalnızca açık `requireContext=true` isteğine bağlı. Tek fotoğraf çağrısında normalize edilen bölge AI istemcisine aktarılıyor. |
| `src/main/java/com/gorkem/vehicle_inspector/client/AiAnalysisClient.java` | `analyzeSingleImage(Path, String)` tek dosya + bölge multipart isteğini kuruyor. Görüntü nedeniyle gelen HTTP 400 için Türkçe yeniden çekim yönlendirmesi sunuluyor. Eski overload'lar korunuyor. |
| `src/main/java/com/gorkem/vehicle_inspector/controller/DamageInspectionController.java` | Eski parametrelerin uyumluluk anlamı belgelendi; endpoint sözleşmesi korunuyor. |
| `ai-service/main.py` | Bölge her iki akıştan önce normalize/doğrulanıyor. Tek fotoğraflı analiz artık bölgeyi alıyor; explicit context isteği legacy yola gidiyor. Upload kapatma ve inference kilidi korunuyor. |
| `ai-service/app/damage_analyzer.py` | Kısmi araç fallback'i, aynı fotoğrafta eşleştirme ve bölge düzeltmesi. Mevcut fotometrik kontroller ortak kullanılıyor. Desteklenen dosyalar doğrudan Pillow codec'leriyle açılıyor; bozuk dosya nedeniyle Ultralytics'in çalışma anında HEIF paketi kurma girişimi önleniyor. |
| Testler | Flutter'da `single_photo_flow_test.dart`; Python'da `test_single_photo_analysis.py`, `test_single_photo_api.py` ve mevcut analyzer testleri; Java'da `AiAnalysisClientTest`, `DamageInspectionControllerTest`, mevcut servis/persistence mock'ları. |

`FileStorageService`, entity/DTO/repository ve veritabanı şeması incelendi; değişiklik gerekmiyor. Mevcut volume yolları, sahiplik kontrolleri ve dosya boyutu/MIME doğrulaması kullanılıyor. Eski context alanları/dosyaları için toplu silme veya migration yoktur. Abonelik, kredi/kota rezervasyonu, auth, Gemini, fiyat tahmini, PDF, bakım, Firebase ve AI Asistan mantığı değiştirilmedi.

## Görüntü analizi ve güven sınırları

- Genel model aracı bulduğunda önceki %5 padding'li crop yolu ve koordinat dönüşümü aynıdır.
- Genel model kısmi aracı bulamazsa mevcut parça modeli orijinal görüntü üzerinde çalışır. Yalnızca bilinen araç parçası etiketleri fallback için kanıt kabul edilir. Sırf bir hasar tahmini olması fotoğrafı geçerli yapmaz.
- Bu kanıt varsa hasar modeli aynı fotoğrafın tamamında çalışır. Yeni resize, uzaklık/yakınlık eşiği veya küçük hasarı eleyecek confidence değişikliği yoktur. Parça çıkarımı yeniden kullanılabilir; aynı fallback fotoğrafında iki kez çalıştırılmaz.
- Hasar ve parça bounding box'ları aynı görüntünün koordinatlarında, mevcut overlap kuralıyla eşleştirilir. Eşleşme bulunamazsa `UNKNOWN` kalır.
- `FRONT`/`REAR`, mevcut düzeltme tablosuyla yalnızca tampon, kapı, tekerlek ve yan cam çiftlerine uygulanır. `UNKNOWN`, far, kaput gibi eşleşmemiş/çift olmayan parçalar bu seçimden türetilmez.
- Hasar yoksa `NO_VISIBLE_DAMAGE` / `NONE` / `NO_ACTION` sözleşmesi korunur. Şiddet ve onarım önerisi kuralları aynıdır.
- Mevcut karanlık/blur eşikleri ve Pillow piksel güvenliği korunur. JPEG/PNG/WEBP decoder'ları dışında yeni görüntü biçimi veya bağımlılık eklenmez.

## Eski istemci uyumluluğu

| İstek | Davranış |
| --- | --- |
| Yeni mobil: tek dosya, `vehicleRegion`, context flag'i yok | Tek fotoğraflı analiz; eski context dosyası olsa bile kullanılmaz/doğrulanmaz/silinmez. |
| Eski mobil: `context-image`, `context-image-quality`, `requireContext=true` | Mevcut iki fotoğraflı analiz ve ikinci fotoğraf doğrulaması korunur. |
| Daha eski çağrı: bölge parametresi yok | Endpoint isteği kabul etmeye devam eder; bölge düzeltmesi uygulanmaz. Güncel mobil seçim yapmadan göndermez. |
| FastAPI'ye doğrudan `context_image` gönderimi | Legacy `analyze_pair` ve fotoğraflar arası eşleştirme korunur; yeni mobil/backend yolu bunu kullanmaz. |

Uyumluluk kodu, desteklenen tüm mobil sürümler tek fotoğrafa geçmeden ve mevcut erişim kayıtlarından legacy endpoint/parametre kullanımının kalmadığı doğrulanmadan kaldırılmamalıdır. Kaldırma ayrı bir sürümde yapılmalı; geçmiş context dosyaları ve alanlarının veri saklama kararı bundan ayrı tutulmalıdır. Bu PR ek ölçüm altyapısı kurmaz.

İleride yayın sırası: iki sözleşmeyi destekleyen AI servisi → backend → yeni mobil. Bu görevde deploy/Railway yapılandırması yapılmadı. Master'a birleştirme ayrıca kullanıcı onayı gerektirir ve normal merge kullanılmalıdır.

## Test ve model karşılaştırması

- Flutter: **60/60 test başarılı**. `flutter analyze --no-pub` temiz; değişen üç Dart dosyası format kontrolünden geçti. Yeni beş test; kamera/galeri, ön/arka zorunluluğu, tek multipart, işlem sırasında tekrarlanan basma, kalite reddi/fotoğraf değiştirme ve yeniden denemeyi kapsar. Mevcut iki tema, küçük ekran, landscape, tablet ve büyük yazı testleri geçer.
- Java: **197 başarılı, 10 atlanan, 0 hata**. Atlananlar, açıkça disposable PostgreSQL URL'si gerektiren `InspectionPersistenceTest` senaryolarıdır. Bölge aktarımı gerçek RestTemplate multipart testleriyle; legacy endpoint'ler MockMvc ile; quota/rol/sahiplik/hasarsız sonuç kuralları mevcut servis testleriyle kontrol edildi. Persistence mock'ları yeni tek fotoğraf çağrısına uyarlandı.
- Python hasar/API/lifecycle alt paketi: **50/50 başarılı**. Yeni 21 test; kısmi görüntü, tüm mevcut hasar sınıfları, düşük confidence çizik, UNKNOWN, bölge, eski crop koordinatları, karanlık/blur, MIME/boyut, bozuk dosya/piksel güvenliği, ASGI multipart ve legacy çift fotoğraf routing'ini kapsar. HTTP test istemcisi paketi eklenmedi.
- Python tüm paket: **113 test, 111 başarılı, 2 mevcut hata**. `test_rejects_private_rag_with_backend_tool` ve `test_rejects_web_route_with_private_user_tool` testlerinin beklediği hata metni, mevcut semantic router'ın döndürdüğü `invalid boolean` mesajıyla uyuşmuyor. İlgili test dosyası dokunulmamış `master` kopyasında da aynı iki hatayı verdi (10 test, 2 hata). AI Asistan koduna veya bu testlere müdahale edilmedi.

Gerçek YOLO ağırlıklarıyla yerel dört örnek; bölge belirtilmeden ve `FRONT`/`REAR` ile denendi. Üç model dosyasının SHA-256 hash'leri değişmedi:

| Örnek | Önceki tek fotoğraf yolu | Yeni tek fotoğraf yolu (bölge belirtilmeden) |
| --- | --- | --- |
| `hasarlıaraç1.jpg` | SCRATCH / HOOD | Sonuç nesnesi aynı; detection, confidence ve koordinatlar dahil. |
| `carsc.jpg` | Araç bulunamadığı için ret | SCRATCH + DENT; FRONT_WHEEL |
| `scratch.jpg` | Araç bulunamadığı için ret | SCRATCH; FRONT_BUMPER |
| `scratch1.jpg` | Araç bulunamadığı için ret | SCRATCH; parça UNKNOWN, güvenilir affectedParts listesi boş |

Ayrıca gerçek pipeline'da karanlık, bulanık ve araç olmayan checkerboard kontrol görüntüleri reddedildi. Yerel karşılaştırma çıktıları Git tarafından yok sayılan `ai-service/evaluation-runs/single-photo-before.json` ve `single-photo-after.json` dosyalarındadır; test görüntüleri/ağırlıklar PR'a eklenmez.

Bu dört fotoğraf etiketli bir doğrulama kümesi değildir; genel doğruluk veya hafif/derin çizik ayrımı için istatistiksel regresyon güvencesi sağlamaz. Bu PR yeni bir derinlik sınıfı üretmez. Kısmi temiz araç ve kırık senaryoları deterministik model çıktılarıyla test edilmiştir; kapsamlı etiketli görüntü değerlendirmesi yayından önce ayrıca yapılmalıdır. Gerçek telefon kamera izinleri, üretim veritabanı ve uçtan uca Gemini/PDF akışı bu görevde çalıştırılmadı.

Kontrol komutları:

```powershell
cd mobile
flutter analyze --no-pub
flutter test --no-pub
# Değişen Dart dosyalarında: dart format --output=none --set-exit-if-changed ...
cd ..
.\mvnw.cmd -q test
cd ai-service
.\venv\Scripts\python.exe -m unittest discover -s tests -p test_damage_analyzer.py
.\venv\Scripts\python.exe -m unittest discover -s tests -p 'test_single_photo*.py'
.\venv\Scripts\python.exe -m unittest discover -s tests -p test_resource_lifecycle.py
.\venv\Scripts\python.exe -m unittest discover -s tests
```
