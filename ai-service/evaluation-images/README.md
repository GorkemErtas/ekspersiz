# Gerçek Görsellerle Manuel Hasar Modeli Değerlendirmesi

Bu klasöre model karşılaştırması için izinli gerçek araç fotoğrafları koyun. Görseller Git tarafından izlenmez; özel fotoğrafları repoya eklemeyin. `review_manifest.csv` şablonunu kullanın.

## Manifest alanları
- `image`: Bu klasöre göre görsel yolu.
- `expected_damage`: `true`, `false` veya bilinmiyorsa boş.
- `expected_types`: Beklenen hasar sınıfları, `|` ile ayrılır.
- `notes`: Aydınlatma, açı, görünürlük veya hata notları.

**Aktif beş sınıflı CarDD modelinin çıktı sınıfları:** `SCRATCH`, `DENT`, `CRACK`, `BROKEN_PART`, `BROKEN_GLASS`.

`PAINT_DAMAGE` ve `DEFORMATION` geniş uygulama taksonomisinde yer alsa da aktif CarDD beş sınıflı modelin **doğrudan tahmin ettiği sınıflar değildir**. `NO_VISIBLE_DAMAGE` de öğrenilmiş bir sınıf değil, sistemin sonuç durumudur.

Temiz araçlar, küçük/büyük hasarlar, farklı kamera/açı/ışık koşulları ve yanlış pozitif örnekleri birlikte değerlendirin. Aynı veri kümesini tüm karşılaştırılan modeller için kullanın; bağımsız test görüntülerini eğitim amacıyla kullanmayın.
