# Fotoğraf analizi 422 düzeltmesi — 25 Ekim 2026

## Doğrulanan hata yolu

Yükleme `FileStorageService` içinde boyut, MIME ve dosya imzasını kontrol eder;
fotoğrafın piksel sayısını veya gerçek decode sonucunu kontrol etmez. Bu nedenle
48 MP bir JPEG, 10 MiB altında olduğunda yüklemeden 200 alabilir.

FastAPI `/api/v1/validate-image`, teknik ret için de **HTTP 200** döndürür.
Başarı ölçütü gövdedeki `suitable` alanıdır. `DamageInspectionService`, yakın detay
ve ardından genel görünüm için `suitable:false` gördüğünde
`UnsuitableInspectionImageException` üretir. `GlobalExceptionHandler` bunu 422'ye
çevirir; Gemini çağrısı henüz başlamamıştır. Flutter zaten sunucunun `error`
alanını kullanıcıya gösterir.

Düzeltmeden önce gerçek, sentetik **8000×6000 / 48 MP / 773.218 bayt** JPEG ile
`suitable:false, code:INVALID_IMAGE` ve 24 MP ret mesajı yeniden üretildi.
Bu, yalnız JPEG kalitesini 90 yapmakla çözünürlüğün sınırlanmadığını doğrular.
FastAPI'nin eksik multipart alanları için ürettiği 422 farklı bir hata yoludur;
Java istemcisi `image` ve `context_image` alanlarını doğru gönderir.

Railway production kayıtları salt okunur incelendi: 25 Ekim'deki üç
`validate-image` isteği 200 dönmüş, eski loglar `suitable`/ret nedeni içermiyor.
Dolayısıyla geçmişteki belirli kullanıcı fotoğrafının 24 MP, yetersiz ayrıntı veya
başka bir teknik kontrolden hangisine takıldığı kesin olarak söylenemez.
Koddaki 422 kaynağı ve çözünürlük uyumsuzluğu yeniden üretimle doğrulanmıştır.

## Değişiklikler

| Dosyalar | Davranış |
| --- | --- |
| `mobile/lib/features/inspection/services/inspection_image_optimizer.dart` | JPEG/PNG/WEBP gerçek decode, en fazla 2048 piksel uzun kenar, en az 256 piksel kısa kenar; oran ve EXIF yönü korunarak JPEG kalite 90; beyaz üzerine alfa birleştirme; EXIF/GPS taşınmaz. |
| `mobile/lib/features/inspection/screens/upload_damage_image_screen.dart` | Her iki fotoğraf aynı optimizasyondan sonra önizlenir ve yüklenir. İşleme sırasında ikinci seçim/yükleme engellenir. Sabit `.jpg` adları ve `image/jpeg` kullanılır. |
| `mobile/pubspec.yaml`, `mobile/pubspec.lock` | Zaten kullanılan `image` 4.10.1 doğrudan ve sabit bağımlılık yapıldı. |
| `ai-service/app/damage_analysis/images.py`, `api.py` | Boyut, biçim, hareketli görüntü, yüksek/düşük çözünürlük, ayrıntı ve decode retleri ayrı hata kodları alır. Validasyon sözleşmesi korunur. |
| Java `UnsuitableInspectionImageException`, `GlobalExceptionHandler`, `DamageInspectionService` | 422 mesajında fotoğraf rolü ve neden; `validationErrors.code` ve `validationErrors.imageRole`. Loglarda yalnız izin verilen sabit kod ve rol, HTTP durumu bulunur. |
| Flutter, Python, Java testleri ve `mobile/test/fixtures/inspection/` | Sentetik kaynaklarla regresyon ve gerçek Flutter çıktısından FastAPI/mock Gemini'ye sözleşme kontrolü. Fixture üretici betiği dahildir. |

Sunucu sınırları **10 MiB / 24 MP** olarak kaldı. Kaynak görseli cihazda işlemek
için ayrı **40 MiB / 64 MP** üst sınır vardır: dosya boyutu okumadan önce ve sonra,
piksel sayısı header'dan tam decode öncesinde kontrol edilir. Bunlar sunucunun
kabul sınırlarını değiştirmez. 48 MP ve yükleme sınırını aşan makul kaynaklar
yerel olarak küçültülür; sınırsız kaynak decode edilmez. JPEG kodlama isolate'ta
çalışır; native görüntü kaynakları `finally` içinde serbest bırakılır.

Picker'da önceden yeniden kodlama yapılmaz; hareketli görüntülerin kontrol öncesi
tek kareye dönüşmesi önlenir. Desteklenmeyen/bozuk/hareketli dosyalar, küçük
görüntüler ve aşırı panoramalar anlaşılır mesajla reddedilir. AI'ın görsel ayrıntı,
iki farklı fotoğraf ve diğer güvenlik kontrolleri sürer. İki fotoğraflı Gemini
isteği, kredi/rapor iş akışı ve veritabanı şeması değiştirilmedi.

## Doğrulama

| Kontrol | Sonuç |
| --- | --- |
| Flutter `test/features/inspection` | 76 geçti |
| Flutter statik analiz | Sorun yok |
| Java: servis, controller, AI istemcisi, depolama, inceleme ve kredi kalıcılığı | 98 geçti, 0 atlandı |
| Python: Gemini/FastAPI, servis güvenliği, kaynak yaşam döngüsü | 27 geçti, 0 atlandı |

Flutter testleri 48 MP JPEG, 10 MiB üzeri PNG, WEBP, sekiz EXIF yönü (aynalar
dahil), transparan PNG, APNG/animated WEBP, bozuk/küçük/desteklenmeyen kaynakları
kapsar. Gerçek optimize JPEG'ler `mobile/build/inspection-image-contract/` altına
yazılır; FastAPI bunları doğrular ve iki fotoğrafla **tek mock Gemini çağrısına**
ilerler. Geçersiz görsellerde Gemini çağrılmaz. Java testleri iki fotoğraf rolünde
de ret sonrası kredi rezervasyonunun bırakılmasını ve 422 mesajının korunmasını
doğrular. Ücretli canlı Gemini çağrısı ve fiziksel Android/iOS cihaz testi yapılmadı.

Java kalıcılık testleri yalnız `127.0.0.1:55439` üzerindeki
`credit_system_test` ve `vehicle_inspector_test` veritabanlarında çalıştırıldı.

Tekrar çalıştırma (PowerShell, repo kökü; Flutter testi `mobile` içinde):

```powershell
Push-Location mobile
flutter pub get --offline
flutter test --no-pub test/features/inspection --reporter expanded
flutter analyze --no-pub
Pop-Location

$env:FLUTTER_IMAGE_CONTRACT_DIR = "$PWD/mobile/build/inspection-image-contract"
Push-Location ai-service
.\venv\Scripts\python.exe -m unittest discover -s tests -p test_gemini_vision.py
.\venv\Scripts\python.exe -m unittest discover -s tests -p test_service_security.py
.\venv\Scripts\python.exe -m unittest discover -s tests -p test_resource_lifecycle.py
Pop-Location

.\mvnw.cmd '-Dtest=DamageInspectionServiceTest,DamageInspectionControllerTest,AiAnalysisClientTest,FileStorageServiceTest,InspectionPersistenceTest,CreditWalletPersistenceTest' '-Dcredit.test.jdbc-url=jdbc:postgresql://127.0.0.1:55439/credit_system_test' '-Dcredit.test.username=gemini_test' '-Dinspection.test.jdbc-url=jdbc:postgresql://127.0.0.1:55439/vehicle_inspector_test' '-Dinspection.test.username=gemini_test' test
```

PostgreSQL komutu yalnız önceden hazırlanmış, silinebilir yerel test veritabanları
içindir. Flutter çıktısı ortam değişkeni verilmezse Python'un bu katmanlar arası
testi açıkça atlanır; bu çalışmada değişken verilip test çalıştırıldı.

## Yayın gereksinimleri

- Railway backend ve AI servisi yeni master commitlerini kullanmalı. GitHub
  autodeploy etkinse push bunu başlatabilir; ayrıca manuel deploy yapılmadı.
- Otomatik fotoğraf optimizasyonu için **yeni Flutter AAB ve uygulama güncellemesi
  gerekir**. Mevcut sürüm `1.0.0+46`; yayın sırasında Play Console'daki son build
  numarasından yüksek numara kullanılmalı. Bu görevde AAB üretilmedi/yayınlanmadı.
- Daha önce yüklenmiş yüksek çözünürlüklü fotoğraflar güncel uygulamada yeniden
  seçilip yüklenmeli. Eski saklanan dosyalar topluca değiştirilmedi.
- Migration, yeni secret, kota artışı veya AI güvenlik limiti değişikliği gerekmez.

Codec hedef boyutu ve oran davranışı için [Flutter ImageCodec dokümantasyonu](https://api.flutter.dev/flutter/dart-ui/instantiateImageCodec.html).
