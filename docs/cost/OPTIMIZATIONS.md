# Maliyet ve bellek optimizasyonları

24 Ekim 2026: Önceki görüntü modelleri, eğitim/değerlendirme ve benchmark araçları kaldırılmıştır. Railway dağıtımları kaldırılmış olduğundan bu belge çalışan üretim ölçümü iddia etmez. Tarihsel fatura referansı [başlangıç maliyetlerinde](BASELINE_2026-10-15.md) korunur.

| Katman | Korunan uygulama | İzlenecek etki |
| --- | --- | --- |
| AI Asistan / RAG | E5 embedding modeli ve retriever ilk kullanımda kilitle tek kez oluşturulur | İlk sorgu gecikmesi ve süreç belleği |
| Python imajı | CPU PyTorch ve yalnızca asistan runtime bağımlılıkları; embedding modeli imaja alınır | İmaj boyutu, soğuk başlangıç ve RAG belleği |
| Spring Boot | JVM varsayılanı `-Xms128m -Xmx768m`; varsayılan HikariCP havuzu | Gerçek yük altında RSS, GC ve bağlantı beklemesi |
| Dosya / mobil | Sınırlı dosya boyutu, güvenli stream yaşam döngüsü ve oturuma bağlı fotoğraf önbelleği | I/O ve geçmiş görsel erişimi |

Yeni model entegre edildiğinde gerçek doğruluk, p95 gecikme, RAM ve eşzamanlı yük yeniden ölçülmelidir. Önceki görüntü modelinin bellek veya fatura ölçümleri yeni altyapının garantisi değildir. Aylık tasarruf oranı iddia edilmez.
