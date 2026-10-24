# Gerçek transfer öğrenme sonuçları

Validation ve yerel CPU koşullarıyla seçilen aday: **rtdetr-r18**. **Üretim için yeterli değil; aktivasyon ve deploy yapılmadı.**

## Aynı tarihsel test üzerindeki hasar tespiti

| Model | mAP50:95 | mAP50 | Precision | Recall | FP | CPU medyan | Tepe RAM |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| YOLOX-Tiny 416 | 1.32% | 3.92% | 15.86% | 4.91% | 244 | 86.8 ms | 118.9 MiB |
| nano-384 | 4.18% | 8.65% | 16.72% | 17.74% | 827 | 297.8 ms | 283.8 MiB |
| nano-512 | 7.27% | 14.16% | 21.39% | 25.64% | 882 | 472.6 ms | 371.3 MiB |
| seg-nano-384 | 6.23% | 12.20% | 20.90% | 21.37% | 757 | 539.7 ms | 352.1 MiB |
| rtdetr-r18 | 6.28% | 12.50% | 10.70% | 30.56% | 2387 | 445.1 ms | 325.7 MiB |

**Validation ön seçimi testte en yüksek mAP’yi korumadı.** Tarihsel testte en yüksek bbox mAP50:95 `nano-512` adayında ölçüldü. Bu gözlem, test kullanılarak yeni bir üretim seçimi yapılmış gibi sunulmaz. Hiçbir aday üretim için seçilmedi.

81 hasar etiketli görüntü, 936 gerçek hasar kutusu. AP: COCO bbox IoU 0.50:0.95, skor tabanı 0.001; P/R/FP: skor 0.25, IoU 0.5, sınıf uyumlu eşleştirme. Test görüntüleri veya etiketleriyle model/eşik seçilmedi. Bu daha önce görülmüş tarihsel karşılaştırma setidir; yeni ve kör bir üretim kabul seti değildir.

Baseline kendi validation sonucuna göre 416 girişle tutuldu: validation hasar mAP50:95 416 için 0.02267, 640 için 0.01888. Eski farklı sınıfları birlikte eşleştiren P/R hatası ortak evaluator ile düzeltildi; bu düzeltme COCO mAP’yi değiştirmez. Tablodaki iç test sonuçları baseline dahil gerçek ONNX CPU çıktılarındandır. Tarihsel Torch çıktıları JSON’da ayrı tutulur; export sayısal farkları metrik düzeltmesi veya model kazanımı sayılmaz.

## Validation ile seçilen çalışma noktası

| Model | Eşik | Validation precision koşulu | Test precision | Test recall | TP | FP |
| --- | ---: | --- | ---: | ---: | ---: | ---: |
| nano-384 | 0.250 | sağlanamadı | 16.72% | 17.74% | 166 | 827 |
| nano-512 | 0.825 | sağlandı | 87.50% | 0.75% | 7 | 1 |
| seg-nano-384 | 0.250 | sağlanamadı | 20.90% | 21.37% | 200 | 757 |
| rtdetr-r18 | 0.275 | sağlanamadı | 12.17% | 28.63% | 268 | 1934 |

Precision koşulu tek başına yeterli değildir. Nano 512’nin yüksek eşikteki precision değeri çok az tahmine dayanır; recall çok düşüktür. Üstteki eşit 0.25 eşik karşılaştırması bu çalışma noktasıyla karıştırılmamalıdır. Hiçbir aday gerekli precision ve recall’u birlikte sağlamaz.

## CPU ve RAM

| Model | Fotoğraf | Medyan | p95 | Tepe RAM |
| --- | --- | ---: | ---: | ---: |
| YOLOX-Tiny 416 | medium | 86.8 ms | 102.4 ms | 118.9 MiB |
| YOLOX-Tiny 416 | large | 188.4 ms | 208.1 ms | 206.6 MiB |
| YOLOX-Tiny 416 | camera | 157.4 ms | 180.2 ms | 176.2 MiB |
| nano-384 | medium | 297.8 ms | 330.1 ms | 283.8 MiB |
| nano-384 | camera | 414.3 ms | 450.6 ms | 347.6 MiB |
| nano-384 | large | 439.5 ms | 478.3 ms | 376.9 MiB |
| nano-512 | medium | 472.6 ms | 520.5 ms | 371.3 MiB |
| nano-512 | camera | 591.0 ms | 656.7 ms | 432.8 MiB |
| nano-512 | large | 644.3 ms | 682.3 ms | 462.6 MiB |
| seg-nano-384 | medium | 539.7 ms | 589.4 ms | 352.1 MiB |
| seg-nano-384 | camera | 657.4 ms | 697.6 ms | 414.9 MiB |
| seg-nano-384 | large | 693.7 ms | 756.6 ms | 444.8 MiB |
| rtdetr-r18 | medium | 445.1 ms | 478.8 ms | 325.7 MiB |
| rtdetr-r18 | camera | 559.2 ms | 591.9 ms | 386.4 MiB |
| rtdetr-r18 | large | 596.4 ms | 642.4 ms | 415.9 MiB |

Ayrı Torch içermeyen süreçler, iki ONNX inference thread’i, fotoğraf başına iki ısınma ve 20 ölçüm; her modelin validation ile seçilen bundle eşiği kullanılır. Decode, kalite kontrolü, ön işleme, iki görevin forward işlemleri, kutu çözümü/NMS ve parça eşleştirmesi dahildir. `medium`: 637×419 HITL PNG; `camera`: 8 MP SYNDCAR fotoğrafından JPEG; `large`: 4032×3024 türetilmiş 12 MP JPEG. Son ikisi eşit kaynak tüketimi için kullanılır; bağımsız hasar vakası sayılmaz. JVM, E5/RAG, ağ ve Gemini dahil değildir. Gerçek Railway kotası veya yük testi yapılmadı.

## Validation adayının sınıf sonuçları

| Sınıf | Test desteği | mAP50:95 | Precision | Recall | FP | FN |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Broken part | 156 | 13.01% | 19.27% | 53.85% | 352 | 72 |
| Corrosion | 27 | 4.55% | 6.45% | 14.81% | 58 | 23 |
| Cracked | 8 | 1.88% | 0.00% | 0.00% | 22 | 8 |
| Dent | 173 | 3.91% | 10.37% | 28.90% | 432 | 123 |
| Flaking | 23 | 0.89% | 2.34% | 17.39% | 167 | 19 |
| Missing part | 57 | 22.23% | 26.05% | 54.39% | 88 | 26 |
| Paint chip | 116 | 1.01% | 4.36% | 14.66% | 373 | 99 |
| Scratch | 376 | 2.74% | 9.69% | 25.53% | 895 | 280 |

## Detection ve segmentation

`seg-nano-384` gerçek maske eğitimi/testi: mask mAP50:95 **5.44%**, mask mAP50 **11.04%**. Aynı bbox API’sine aktarımda mask head dışarıda bırakıldı; maskeler API’ye yeni alan olarak eklenmedi.

Nano 384/512, öğrenme oranı ve çözünürlük bakımından; Seg Nano ayrıca mimari ve bbox/mask uyumlu crop bakımından farklıdır. Sonuçlar tek bir değişkenin nedensel etkisi veya bütün modeller arasında optimum diye sunulmaz. Ek RT-DETR R18 adayı çok ölçekli CNN, 640 giriş ve framework-native eğitim ayarları kullanır. Bu aşama RF-DETR test sonuçlarından sonra, ayrı protokolle eklenmiştir; checkpoint ve aday seçimi yalnızca validation üzerinden yapılır.

## Ayrı kaynak: SYNDCAR v1

| Model | İki sınıf mAP50:95 | mAP50 | Precision | Recall | FP |
| --- | ---: | ---: | ---: | ---: | ---: |
| YOLOX-Tiny 416 | 0.00% | 0.01% | 0.00% | 0.00% | 27 |
| nano-384 | 0.64% | 2.83% | 18.10% | 5.65% | 172 |
| nano-512 | 2.38% | 6.84% | 15.93% | 10.70% | 380 |
| seg-nano-384 | 1.51% | 4.36% | 21.39% | 6.39% | 158 |
| rtdetr-r18 | 1.56% | 4.96% | 10.25% | 12.93% | 762 |

CC BY 4.0 kaynak; eğitimde kullanılmayan 245 görüntü ve 673 ortak `Cracked`/`Scratch` kutusu. Diğer kaynak sınıfları ve bunlara ilişkin tahminler ortak sınıf skoruna girmez. Aynı küçük araç/sentetik hasarın çok sayıda yakın görünümü vardır; 245 bağımsız gerçek olay veya temiz negatif seti değildir. Alan farkındaki düşük sonuçlar üretim genellemesi iddiasını desteklemez.

## Uyumluluk ve yayın kararı

Tüm adayların aynı testte ONNX/PyTorch metrik farkı kontrolü: **geçti**. mAP50, mAP50:95, precision ve recall için mutlak tolerans 0.0001. 512 modelinin 12 MP kontrolünde düşük skorlu proposal satırları ham tensor allclose kontrolünü geçmedi; API tespit kümesi eşleşti. Bu sınır `TRANSFER_EXPORT_DIAGNOSTICS.json` içinde açıkça kaydedildi.

Parça modeli, katalog, 416 ön işleme, confidence 0.25 ve baseline NMS 0.45 korundu. İlk export’taki NMS 0.50 farkı incelemede düzeltildi; yeni bundle dizinleri oluşturularak üç tam test parity kontrolü ve tüm CPU ölçümleri tekrarlandı. Parça P/R ve mAP farkı baseline’a karşı 0.0001 sınırının altında doğrulandı. Hasar ağırlığı, seçimi ve postprocess’i değişmedi.

Bu çalışmadaki INT8 ve parça kanıtına göre hasar eleme deneyleri validation doğruluğunu düşürdüğü için seçilmedi. RT-DETR NMS taramasında da önceden yazılan precision kazancı / recall kaybı koşulları sağlanmadı; native decoder korundu (`TRANSFER_RTDETR_VALIDATION_DIAGNOSTICS.json`). Validation eşik aramasında istenen precision 0.70 koşulu sağlanamadığında başarısızlık açıkça kaydedildi. Doğrulanmış temiz negatif veri olmadığı için gerçek hasarsız fotoğraf yanlış alarm oranı ölçülemedi.

Üretim için eksikler: yeterli nadir sınıf örneği, uzman semantik etiket incelemesi, izinli temiz/araç dışı negatifler, yeni araç/çekim oturumu ayrılmış kör saha holdout’u, hasar-parça ilişki doğruluğu ve gerçek Railway kaynak/yük ölçümü. Mevcut P/R/mAP değerleri önceden yazılan yayın koşullarını birlikte sağlamaz. Analiz bayrakları ve bütün model onayları kapalıdır; geçmiş, rapor, asistan/RAG ve kredi sözleşmeleri korunur.

Ayrıntılar: [ölçümler](TRANSFER_RESULTS.json), [gerçek eğitim kayıtları ve başarısız denemeler](TRANSFER_TRAINING_RUNS.json), [yöntem ve tekrarlama](TRANSFER_LEARNING.md), [veri incelemesi](TRANSFER_DATA_AUDIT.json), [ayrımlar arası görsel benzerlik](TRANSFER_SPLIT_SIMILARITY.json), [ayrı veri/framework/ağırlık lisansları](COMMERCIAL_LICENSE_REVIEW.md), [test doğrulaması](TRANSFER_VALIDATION.json).
