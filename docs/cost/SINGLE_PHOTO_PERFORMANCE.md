# Fotoğraf depolama ve istemci performansı

Önceki görüntü modelinin benchmark'ları ve ölçüm scriptleri kaldırılmıştır. Güncel hasar analizi durumu: [API sözleşmesi](../SINGLE_PHOTO_ANALYSIS.md).

Korunan bağımsız davranışlar:

- Flutter fotoğraf seçimi, 10 MiB üzerindeki dosyayı mümkün olduğunda baytları okumadan reddeder.
- `FileStorageService` dosya imzasını kontrol eder, stream'leri kapatır ve mevcut dosyaların üzerine yazmaz. Başarısız yeni yazımın kendi dosyası temizlenir.
- Geçmiş fotoğraf önbelleği kullanıcı oturumu/sahiplik kontrollerine bağlıdır.

Bu davranışlar `single_photo_flow_test.dart`, `inspection_image_cache_test.dart` ve `FileStorageServiceTest` ile sınanır. Önceki model için ölçülen süre veya bellek değerleri yeni bir modele genellenmez.
