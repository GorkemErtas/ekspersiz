# HITL / YOLOX-Tiny gerçek sonuçlar — 24 Ekim 2026

**Karar: Üretim için onaylanmadı; hasar analizi kapalı kalır.** Parça tespiti öğrenilmiş olsa da hasar recall değeri yetersizdir. Düşük maliyetli çıkarım, doğruluk eksiğini gidermez.

## Veri ve eğitim

Ham veri 1.812 görüntü / 24.851 poligondur. Bir geçersiz görüntü bütünüyle dışlandı; 441 piksel eşinin tamamlayıcı etiketleri birleştirildi. Kullanılabilir 1.370 görüntü / 24.819 poligon; split 1.095 / 137 / 138. Ham dosyalar değişmedi. [Sınıf başına sayılar](HITL_CLASS_COUNTS.md), [tam veri denetimi](HITL_DATASET_AUDIT.json).

Tek Tiny omurga + 8/21 sınıflı iki head, **6,105,189 parametre**. Hazır ağırlık kullanılmadı. 50 epoch tamamlandı; validation ortalama iki görev mAP50:95 ölçütüyle **30. epoch** checkpoint'i seçildi. Test kümesi seçimden sonra bir kez değerlendirildi; ONNX doğrulaması aynı dondurulmuş testin yeniden çalıştırılmasıdır.

Donanım: RTX 4050 Laptop GPU. Loglanan başarılı epoch süreleri toplamı 53.3 dakika; tepe CUDA tahsisi 1224.5 MiB. İlk değerlendirmedeki sayısal taşma fail-closed davranışıyla durdu; eğitim/çıkarım boyut sınırı düzeltilip son geçerli checkpoint'ten devam edildi. İlk küçük alt küme smoke'u doğruluk kanıtı sayılmadı.

## Bağımsız test — seçilen 416 girişi

| Görev | mAP50 | mAP50:95 | Precision | Recall | F1 |
| --- | ---: | ---: | ---: | ---: | ---: |
| damage | 3.91% | 1.32% | 15.86% | 4.91% | 7.50% |
| part | 70.22% | 36.22% | 70.06% | 69.71% | 69.89% |

Precision/recall/F1 çalışma noktası confidence 0.25, IoU 0.5’tir. Sınıf AP, FP/FN ve confusion matrix [JSON sonuçlarında](HITL_RESULTS.json) bulunur. Etiketsiz görevler negatif sayılmaz. Hasar→parça ilişki doğruluğu için insan etiketli ilişki verisi yoktur; ölçülmüş başarı iddia edilmez.

## Çözünürlük karşılaştırması — validation

| Giriş | Hasar mAP50:95 | Parça mAP50:95 |
| --- | ---: | ---: |
| 416 | 2.27% | 35.37% |
| 640 | 1.89% | 20.15% |

İki giriş aynı 416’da eğitilmiş checkpoint ile karşılaştırıldı; ayrı 640 eğitimi yapılmadı. 416 validation ile seçildi. 640’ın bu koşuda daha kötü olması, yeniden eğitilmiş yüksek çözünürlüğün yararsız olduğu anlamına gelmez.

## Ayrı CPU ONNX süreci — iki thread

| Giriş | Session yükleme | Tek fotoğraf medyanı | p95 | Süreç tepe RAM |
| --- | ---: | ---: | ---: | ---: |
| 416 | 87.8 ms | 65.7 ms | 82.7 ms | 119.0 MiB |
| 640 | 90.6 ms | 123.6 ms | 179.4 ms | 159.7 MiB |

4032×3024 türetilmiş fotoğraf, 416 giriş: medyan 181.4 ms, p95 278.5 ms, tepe süreç belleği 206.5 MiB.

Süreler decode, ışık/netlik, letterbox, iki head forward, NMS ve parça eşleştirmesini içerir. Fotoğraf yükleme, ağ, JVM, Gemini ve E5/RAG belleği kapsam dışıdır. Bunlar yerel CPU ölçümleridir; Railway ölçümü veya fatura tasarrufu iddiası değildir. İzole vision sürecine PyTorch import edilmedi. PyTorch, asistan için üretim imajında korunur.

Her iki çözünürlükte iki head’in tüm çıktıları ONNX/PyTorch karşılaştırmasından geçti. Dondurulmuş test kümesinin ONNX metrik farkları [ayrı parity raporunda](HITL_ONNX_ACCURACY.json); mAP mutlak farkı her iki görevde 0.0001 altında kaldı. Bu sonuç temel modelin düşük hasar başarısını düzeltmez.

## Full-stack ve regresyon

- Python: sürümlü şema, tek fotoğraf, ONNX lazy yükleme, hash/imza kapısı, sınırlı eşzamanlılık, gerçek confidence ve INCONCLUSIVE davranışı.
- Java: eklemeli enum ve V17; ham kanıt/model sürümü saklama; null değişim kararı; mevcut ve yeni kayıt uyumluluğu; eşleştirme/çıktı doğrulaması.
- Flutter/PDF: 29 gerçek sınıfın Türkçe etiketleri, eski değerlerin gösterimi, belirsiz şiddet/değişim ve fiziksel inceleme fiyat başlığı.
- Gemini/asistan: kaynak sınıfları ve belirsizlik aktarılır; kesin olmayan onarım/değişim veya hasarsızlık uydurulmaz. Mevcut fiyat/web ve yetki akışı korunur.

Test sayıları ve yürütme sınırları `HITL_VALIDATION.json` kaydında tutulur. Docker daemon kapalı olduğu için build/run doğrulaması yapılamadı. Canlı ödeme, Gemini/Places, gerçek pgvector/RAG sorgusu ve fiziksel cihaz uçtan uca akışı çalıştırılmadı.

## Üretimden önce

Hasar performansı iyileştirilmeden ve bağımsız olarak doğrulanmadan aktivasyon yapılmamalıdır. Sonraki deneyler için doğrulanmış lisanslı transfer kaynağı veya daha uzun/hedefli sıfırdan eğitim, bağımsız yüksek çözünürlüklü eğitim, küçük nesne ve sınıf dengesinin incelenmesi, temiz/araç olmayan negatifler, görevler arası ilişki etiketleri ve eşik kalibrasyonu gereklidir. Mevcut test seti bu sonraki deneyleri seçmek için kullanılmamalıdır; yeni nihai doğrulama kümesi gerekir.

Model bundle’ları `production_approved: false`; Java, Python ve Flutter varsayılan kapalıdır. Canlı deploy, aktivasyon, branch, commit veya push yapılmadı.
