# Gemini Vision geçişi: yerel doğrulama

25 Ekim 2026. Çalışma `master` üzerinde yapıldı. Deploy, Railway servisi başlatma,
production release veya canlı Gemini fotoğraf çağrısı yapılmadı.

| Kontrol | Sonuç |
| --- | --- |
| Python / FastAPI / Asistan regresyonları | 65 test geçti |
| Java unit ve PostgreSQL integration | 295 geçti; Docker gerektiren 2 test atlandı |
| Flutter genel test paketi | 216 test geçti |
| Flutter statik analiz | Sorun yok |
| Python runtime bağımlılıkları | `pip check` başarılı |
| Asistan framework smoke kontrolü | SentenceTransformers 5.6.0 ve PyTorch 2.13.0+cu130 import edildi; mevcut E5 embedder oluşturuldu |
| Görsel API modülü | PyTorch import etmiyor; Ultralytics, ONNX, ONNX Runtime ve COCO paketleri yerel runtime ortamında yok |
| Eski görsel altyapı | Model, veri, eğitim/evaluation, vendor ve ayrı eğitim ortamları kaldırıldı |

Java'da toplam 297 test raporlandı. Atlananlar `AiAssistantBusinessConcurrencyIT` ve
`AiAssistantServiceConcurrencyIT`: ortamda Docker bulunmadığından Testcontainers
tarafından atlandı. Bunlar başarılı çalışmış gibi sayılmadı.

Veritabanı kontrolleri bu çalışma için oluşturulan ayrı PostgreSQL 18.6 kümesinde,
yalnız `127.0.0.1:55439` üzerinde çalıştı. Test güvenlik kontrollerinin beklediği
`credit_system_test`, `vehicle_inspector_test`, `security_audit_test` adları kullanıldı.
Gerçek kullanıcı veritabanına bağlanılmadı. Geçici sunucu testlerden sonra durduruldu.

## Doğrulanan davranışlar

- Aynı istekte iki rol: OVERVIEW ve DETAIL; native JSON Schema ve ortak sözleşme örneği.
- Eksik/aynı/yanlış formatlı fotoğraf, EXIF temizliği, decode öncesi piksel sınırı,
  kimlik doğrulama ve gövde limiti; uygun olmayan isteklerde ücretli sağlayıcı çalışmıyor.
- Belirsiz şiddetin UNKNOWN kalması, ek fotoğraf durumu, enum/tür ve bulgu tutarlılığı;
  uydurma güven yüzdesi/kutu veya kesin değişim kararı kabul edilmiyor.
- Timeout, rate limit, kesik/bloke/geçersiz sağlayıcı yanıtı ve başarısız API çağrısı.
- Kredi bırakma, başarılı analiz/raporda bir kez tamamlama, yeniden istekte ikinci
  görsel analiz yapmama ve rapor hatasından sonra yalnız raporu yeniden oluşturma.
- Gerçek PostgreSQL üzerinde sahiplik, şirket erişimi, kalıcı kayıt, işlem kilidi ve kredi işlemleri.
- Yeni gözlem/onarım metinlerinin rapora taşınması; eski sonuç ve PDF'lerin okunması.
- İki fotoğraflı Flutter yükleme, tek analiz, erişilebilir durumlar, büyük yazı/çeşitli
  ekran boyutları, ödeme, araç yönetimi, Asistan, onboarding ve güvenli görüntü önbelleği.

Mock testleri gerçek Gemini doğruluğu veya sağlayıcının güvenilirliği ölçümü değildir.
Gerçek fotoğraf kabul seti, ücretli Google proje/billing durumu, hesap kotası ve
gerçek fatura doğrulanmadı. E5 için framework yükleme kontrolü yapıldı; yeni model
eğitimi/indirmesi veya canlı RAG ingestion yapılmadı. Güncellenen uygulama yardım
belgelerinin ingestion adımı mevcut komutla, hedef ortam yapılandırıldığında ayrıca
uygulanmalıdır. Eski kullanıcı/rapor verileri değiştirilmedi.

## Tekrar çalıştırma

Python: `ai-service/venv/Scripts/python.exe -m unittest discover -s ai-service/tests -v`
(çalışma dizini veya `PYTHONPATH`, `ai-service` paketlerini içermelidir).

Backend: `mvnw.cmd -Dtest=*Test,*IT test`. Veritabanı testleri için ilgili
`credit.test.jdbc-url`, `inspection.test.jdbc-url`, `security.test.jdbc-url` ve
username özellikleri **ayrı ve silinebilir test veritabanlarına** verilmelidir.
Standart CI örneği [.github/workflows/credit-system-checks.yml](../.github/workflows/credit-system-checks.yml) içindedir.

Flutter: `flutter test --no-pub --reporter expanded`, ardından `flutter analyze --no-pub`.
Ham yerel kayıtlar ignored `ai-service/target/gemini-*.log` altındadır.

[Mimari, model seçimi, API koşulları ve yapılandırma](GEMINI_VISION_ANALYSIS.md).
