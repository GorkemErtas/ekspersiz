# Hasar analizi sözleşmesi

Güncel birleşik HITL modeli, sürümlü sınıf sözleşmesi, üretim kapıları ve eğitim sonuçları [yeni teknik belgede](ml/UNIFIED_YOLOX_TINY.md) açıklanır. Aşağıdaki kayıt önceki modellerin kaldırılma doğrulamasıdır; yeni model üretim için onaylanmış değildir.

24 Ekim 2026 itibarıyla yeni fotoğraf analizi ve modele bağlı fotoğraf doğrulama geçici olarak kapalıdır. Önceki model uygulaması ve değerlendirme araçları kaldırılmıştır.

Backend'in analiz/doğrulama girişleri, kredi rezervasyonu veya kayıt durumu değişikliğinden önce HTTP 503 döner. Python'un eski görüntü endpoint'leri de kimlik kontrolünden sonra 503 döner. Mobil yeni analiz ekranı durumu açıklar.

Tek/iki fotoğraflı geçmiş kayıtların `imagePath`, `contextImagePath`, hasar ve parça alanları korunur. Bu alanlar veri sözleşmesidir; model bağımlılığı değildir. Sahiplik kontrolleri, güvenli dosya depolama, geçmiş görsellerin indirilmesi, rapor yeniden üretimi ve PDF devam eder.

Yeni sağlayıcı için sınır ve test komutları [AI servis belgesinde](../ai-service/README.md) açıklanmıştır. Java ve Flutter'ın modelden bağımsız analiz akışı testleri sahte sağlayıcı yanıtlarıyla veri/rapor/kredi sözleşmelerini korur; aktif bir hasar modelinin kanıtı değildir.

## Temizlik doğrulaması — 24 Ekim 2026

- Python: 53 test geçti. Kimlik doğrulama, görüntü gövdesini okumadan 503 yanıtı, asistan yönlendirmesi, RAG yardımcıları ve embedding yaşam döngüsü kapsanır.
- Java: 286 test geçti. Bunların 34'ü ayrı, geçici yerel PostgreSQL üzerinde analiz geçmişi, rapor, kredi ve hız sınırı kalıcılığı testleridir. Test sunucusu sonrasında kapatıldı.
- Flutter: 220 testlik tam paket ve yeni geçici kullanılamama testini içeren 7 testlik ekran paketi geçti. `flutter analyze` ve değişen dosyaların son Dart analizi temiz.
- Yerel Python ortamlarında `pip check` temiz; PyTorch ve SentenceTransformers import kontrolü başarılı. Önceki görüntü paketleri ve ağırlıkları bulunmuyor.

Docker daemon kapalı olduğundan imaj build/run doğrulaması yapılmadı. Canlı Gemini, ödeme mağazası, bildirim, gerçek pgvector/embedding sorgusu ve fiziksel cihaz uçtan uca akışları bu yerel testlerin kapsamında değildir. Güncellenen uygulama bilgi belgesi, sonraki dağıtımda `app-only-v2-analysis-unavailable` sürümüyle yeniden ingest edilmelidir; bu çalışmada canlı veritabanına yazılmadı.
