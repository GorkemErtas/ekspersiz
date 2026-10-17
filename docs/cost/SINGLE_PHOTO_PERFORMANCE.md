# Tek fotoğraflı analiz: performans denetimi

17 Ekim 2026. Taban: `master` / `07228ec` (tek fotoğraf PR #21). Kullanıcı yönlendirmesiyle güncel master pull edildikten sonra geliştirme yerel master üzerinde ayrı commit'lerle yapıldı. Üretim verisine, Railway ayarlarına veya çalışan servislere müdahale edilmedi.

## Uygulanan düşük riskli değişiklikler

| Dosya | Değişiklik ve doğrulanabilen fayda |
| --- | --- |
| `ai-service/app/damage_analyzer.py` | Netlik hesabında float64 Laplacian dizisi, ortalamadan çıkarma ve kare alma işlemlerinde yeniden kullanılıyor. NumPy'nin önceki population variance hesabı korunuyor; ikinci büyük float64 dizi tahsisi kaldırılıyor. Parlaklık/netlik eşikleri, piksel verisi ve YOLO çağrıları aynı. |
| `mobile/lib/features/inspection/screens/upload_damage_image_screen.dart` | `XFile.length()` ile 10 MiB üstü dosyalar `readAsBytes()` öncesinde reddediliyor. Okuma sonrası kontrol korunuyor. Testte 64 MiB olarak bildirilen dosya için byte okuma sayısı sıfır; stat sonrasında büyüyen dosya da reddediliyor. Bu koruma picker'ın kendi native bitmap belleğini azaltmaz. |
| `src/main/java/com/gorkem/vehicle_inspector/service/FileStorageService.java` | İmza kontrolü ve kopyalama input stream'leri artık her çıkışta kapatılıyor. Kopyalama/close hatasında yalnızca bu denemede oluşturulmuş yeni dosya temizleniyor. Atomik `CREATE_NEW` mevcut dosyanın üzerine yazılmasını önlüyor. JPEG/PNG/WEBP baytları aynen saklanıyor. |

Testler: `test_photo_quality_memory.py`, `single_photo_flow_test.dart`, `FileStorageServiceTest.java`. Ölçüm aracı: `ai-service/scripts/benchmark_single_photo_pipeline.py`; mevcut bağımlılıkları kullanır, uygulamanın çalışma yoluna eklenmez.

## Önce / sonra ölçümü

Aynı Windows makinesi, Python 3.13.14; 4032 × 3024 RGB sentetik görüntü, her sürümde **üç ayrı süreç**. Kalite ölçümünde yalnızca benchmark için OpenCV tek thread; tracemalloc açık. Model modülü import edilir, kalite ölçümü için ağırlıklar yüklenmez. Medyanlar:

| Ölçüm | Önce | Sonra |
| --- | ---: | ---: |
| Kalite hesabındaki tepe izlenen geçici tahsis | 197,68 MiB | 104,65 MiB |
| Süreç tepe RSS / Windows peak working set | 792,40 MiB | 699,47 MiB |
| Kalite kontrolü duvar saati süresi | 150,10 ms | 102,98 ms |
| Kalite kontrolü CPU süresi | 125,00 ms | 109,38 ms |

Kaldırılan dizi 4032 × 3024 × 8 byte, yaklaşık **93,02 MiB**. Bu sonuç kalite hesabının geçici bellek kazancıdır; model yüklü servis RSS'sinin sürekli aynı miktarda düşeceği anlamına gelmez. Windows CPU sayacı kaba çözünürlüklüdür. Tek makine ve sentetik görüntü süreleri gerçek Railway yükü, p95 veya fatura tasarrufu olarak genellenemez.

Dört mevcut gerçek fotoğraf, bölgesiz / FRONT / REAR olmak üzere **12 önce/sonra analizle** karşılaştırıldı: tüm sonuç nesneleri, bounding box'lar, confidence, hasar/parça eşleştirmesi, şiddet ve onarım önerileri **birebir aynı**. Üç model ağırlığının ve fotoğrafların SHA-256 hash'leri aynı. Bu küçük, etiketsiz küme genel doğruluk veya çizik derinliği için istatistiksel güvence değildir. Gerçek analizlerin yerel medyanı 69,16 → 56,52 ms gözlendi; fotoğraf başına tek ölçüm ve soğuk/sıcak çalışma farkı nedeniyle bunu kanıtlanmış uçtan uca hızlanma saymıyoruz.

Ham ölçümler Git tarafından yok sayılan `ai-service/evaluation-runs/perf-single-photo-before.json` ve `perf-single-photo-after.json` içindedir; fotoğraflar ve ağırlıklar bu çalışmayla Git'e eklenmez. Aynı araçla ölçüm ve karşılaştırma:

```powershell
cd ai-service
.\venv\Scripts\python.exe scripts/benchmark_single_photo_pipeline.py --output evaluation-runs/perf-single-photo-before.json --real-images
# Aynı ortamda optimizasyon sonrası:
.\venv\Scripts\python.exe scripts/benchmark_single_photo_pipeline.py --output evaluation-runs/perf-single-photo-after.json --real-images
.\venv\Scripts\python.exe scripts/benchmark_single_photo_pipeline.py --output evaluation-runs/perf-single-photo-after.json --compare evaluation-runs/perf-single-photo-before.json
```

## İncelenip korunan davranışlar

| Alan | Bulgu / karar |
| --- | --- |
| Çözünürlük, sıkıştırma, EXIF | Picker kalite 90; yeni maxWidth/maxHeight, yeniden sıkıştırma veya metadata silme yok. Küçük çizik kaybını ve yön/koordinat değişimini ölçmeden bu ayarlara müdahale edilmedi. Android picker mevcut sürümünde EXIF kopyalıyor; depolama orijinal yüklenen baytları koruyor. |
| Mobil kopyalar / önizleme | Uint8List kullanılıyor; kurulu http 1.6.0 `MultipartFile.fromBytes` mevcut listeyi stream'e veriyor, burada ikinci tam byte kopyası yok. Önizleme decode genişliği zaten 600–1600 px ile sınırlı; yüklenen fotoğraf bu önizleme için küçültülmüyor. |
| Backend / volume | AI aktarımı FileSystemResource, fotoğraf indirme Resource kullanıyor; Base64/readAllBytes yolu eklenmedi. Mevcut transaction sonrası eski fotoğraf silme ve rollback sonrası yeni fotoğraf temizliği korundu. Tarihî context fotoğrafları, raporlar ve DB şeması değiştirilmedi. Geçmiş yetim dosyalar için doğrulanmış referans/retention envanteri olmadan toplu tarama-silme eklenmedi. Yeni I/O hata temizliği başarısız olursa asıl hataya suppressed exception eklenir; süreç çökmesi sonrası temizlik garantisi yoktur. |
| Decode / NumPy | Dosya verify + RGB decode yolu bozuk dosya ve Pillow piksel güvenliğini koruyor. İkinci RGB kopyası zaten yoktu. Float32 veya farklı grayscale dönüşümü eşik yakınında karar değiştirebileceği için kullanılmadı. |
| YOLO | Lazy singleton, tek inference kilidi, hasarsız tam araçta parça modelini atlama ve kısmi araç fallback'inde parça sonucunu yeniden kullanma zaten var. Model sayısı, ağırlıklar, conf/IoU/imgsz, crop ve küçük hasar kuralları değiştirilmedi. Predictor özel iç alanlarını temizlemek, model unload ve heap trim eklenmedi. |
| Tekrarlanan kalite / aktarım | Normal mobil akışta kalite üç kez hesaplanıyor: mobilin kalite endpoint'i, backend'in analiz öncesi kontrolü, AI analyze içindeki kontrol. Backend → AI fotoğraf aktarımı bu nedenle üç kez. İlki yeniden çekim UX'ini, ikincisi kota öncesi reddi, sonuncusu doğrudan AI çağrısının doğrulamasını koruyor. Dosya sürümüne bağlı güvenli doğrulama kanıtı/cache olmadan bunlar kaldırılmadı; böyle bir mekanizma bu düşük riskli değişikliğin kapsamına eklenmedi. |
| Concurrency | Event loop dışında inference ve transaction içindeki PROCESSING/kota kilitleri korunuyor. Kilidi bekleyen HTTP istekleri sıkıştırılmış byte buffer tutabilir; tek inference kilidi toplam kuyruk belleği için bir sınır değildir. Trafik/kapasite ölçümü olmadan worker veya yeni kabul/kuyruk politikası eklenmedi. |
| Timeout / retry | Mobil analiz 90 s; backend varsayılan bağlantı 5 s, okuma 60 s; bağlantı/okuma hatasında üç deneme ve 2/4 s bekleme var. Backend toplam süresi mobil timeout'u aşabilir; timeout sonrası inference tekrar çalışabilir. Ölçülmüş soğuk başlangıç/p95 ve iptal/idempotency tasarımı olmadan süreler/retry sayıları değiştirilmedi. |
| İş kuralları | FRONT/REAR yalnızca mevcut eşleştirilmiş parçalara uygulanıyor; UNKNOWN ve NO_VISIBLE_DAMAGE korunuyor. Auth/sahiplik, abonelik/kota, Gemini, PDF ve eski istemci uyumluluğu değişmedi. |

## Doğrulama ve sınırlar

- Flutter: **62/62**, `flutter analyze --no-pub` temiz; iki yeni büyük dosya testi dahil.
- Spring Boot: **204 başarılı, 10 atlanan, 0 hata** (214 toplam). Yeni yedi depolama testi stream kapatma, hatalı/kesilen yazma, close hatası, eski dosyanın korunması ve bayt eşitliğini doğruluyor. Atlananlar ayrı disposable PostgreSQL gerektiren mevcut persistence testleri.
- Python: **117 test, 115 başarılı, 2 mevcut failure**. Yeni dört sayısal test, eski NumPy varyansıyla tam eşitliği, sıfır olmayan Laplacian ortalamasını ve parlaklık/netlik eşiklerini doğruluyor. Hasar/API/lifecycle ve yeni bellek testleri toplam **54 başarılı**. İki AI Asistan hata metni uyuşmazlığı önceki master incelemesinde de doğrulandı; ilgili kod/testler değiştirilmedi.
- Gerçek telefon native heap'i, üretim DB/Gemini/PDF uçtan uca akışı ve Railway trafik/maliyet ölçümü yapılmadı. Kalıcı RSS, CPU vCPU-dakika, RAM GB-dakika, ilk istek ve p95 ayrıca aynı fotoğraf/benzer trafikle ölçülmelidir. **Doğrulanmış aylık maliyet tasarrufu iddiası yoktur.**

Gereksiz bir algoritma, yeni bağımlılık/servis, altyapı ayarı veya veri temizleme işi eklenmedi. Geri dönüş, ilgili ayrı kod commit'inin normal revert işlemidir; veri migration'ı gerekmez.
