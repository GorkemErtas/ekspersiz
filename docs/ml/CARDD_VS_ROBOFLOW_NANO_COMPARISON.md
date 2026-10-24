# CarDD / Roboflow V3 Nano: 2026-10-24 yerel karşılaştırması

**Karar: mevcut CarDD modelini koru.** Yeni Nano için güvenilir bir üstünlük
gösterilemedi. Sonuçlar filtrelenmiş mevcut veri üzerinde keşif amaçlıdır;
bağımsız bir dış test kohortu elde edildiği iddia edilmez.

Branch: `feature/cardd-vs-roboflow-nano-comparison`.

## Deney ve kapsam

Yeni giriş noktası: `ai-service/scripts/compare_cardd_roboflow_nano.py`.
Üretim evaluator'ı veya sınıf sözleşmeleri değiştirilmez. İki checkpoint kendi
özgün sınıf başlıklarıyla okunur; ortak değerlendirme adaptörü yalnızca
SCRATCH, DENT, CRACK sınıflarına projeksiyon yapar.

- CarDD ID 0/1/2 → SCRATCH/DENT/CRACK.
- Roboflow ID 5/2/1 → SCRATCH/DENT/CRACK.
- CarDD BROKEN_PART lamba kırığıdır; RF genel kırık parçayla eşitlenmez.
  Lamba ve cam sınıfları ortak kategoriye otomatik aktarılmaz.
- Aynı fotoğraflar, 640 kare letterbox, NMS IoU .60, AP conf .001,
  native head üzerinde max_det 300, FP32 ve batch 1.
- AP: sınıf duyarlı confidence sıralı bire bir eşleştirme, IoU .50:.05:.95,
  101 recall noktasında precision envelope. Resmî COCO API veya Ultralytics
  `val` ile sayısal özdeşlik iddia edilmez.
- P/R/F1 ve hata kayıtları sabit conf .25, IoU .50. Testten eşik seçilmez.

5.439 görüntü tarandı. 514 test adayından 106'sı iki eğitim/validation
kaynağından en az birine bağlı sızıntı şüphesi nedeniyle çıkarıldı. SHA-256
(dosya ve RGB), pHash, dosya kökeni ve aday sahnelerde SIFT/RANSAC kullanıldı.
RF testinde CarDD train görüntülerinin yeniden işlenmiş kopyaları görüldü.
Bağlı test bileşenleri de tekilleştirildi.

Ortak olmayan anotasyon içeren görüntü bütünüyle dışlanır. Ham CarDD
etiketleri de kontrol edilir: V2 importer'ın düşürdüğü lastik hasarı gizli
arka plan yapılamaz. 226 ortak adayın model tahminleri görülmeden yapılan
görsel incelemesinde 50 fotoğraf daha, örneğin eksik lamba, kopmuş tampon,
kırık ayna, geniş boya soyulması veya eksik ortak anotasyon şüphesi nedeniyle
çıkarıldı. Kaynak görüntüler ve etiketler değiştirilmedi.

Kalan 176 fotoğraf: 132 CarDD, 44 RF; 217 SCRATCH, 109 DENT, 18 CRACK GT.
Görsel inceleme Codex tarafından yapıldı; bağımsız uzman yeniden anotasyonu
değildir. Araç/oturum kimlikleri yoktur; farklı açı/crop sızıntısı kaçabilir.
CarDD'nin eğitim tarihindeki veri üyeliğini kanıtlayan manifest de yoktur.

## Gözlemsel sonuç

AP50-95, yüzde:

| Sınıf | CarDD | RF Nano | Gözlemsel lider |
|---|---:|---:|---|
| SCRATCH | 29.59 | 13.84 | CarDD |
| DENT | 31.77 | 17.16 | CarDD |
| CRACK | 20.02 | 8.44 | CarDD |

Conf .25'te CarDD: 188 TP, 146 FP, 156 FN. RF: 118 TP, 105 FP, 226 FN.
Confidence ≥.80 olan FP sayısı sırasıyla 10 ve 5. FP, anotasyona karşı
sınıf/kutu eşleştirme hatasıdır; mutlaka gerçekte hasar olmayan alan demek
değildir. Kapsam dışındaki native başlık alarmları ayrıca kaydedilir.

Kaynak ayrımı önemlidir: RF alt kümesinde DENT ve CRACK AP lideri RF Nano'dur,
fakat bu alt kümede 19 DENT ve yalnızca 2 CRACK GT bulunur. Pooled skor
CarDD kaynağına ağırlık verir. Güvenilir sınıf kazananı belirlenemedi.

Tek boş etiketli test adayı sızıntı filtresine takıldı. Gerçekten hasarsız,
bağımsız negatif görüntülerde FP/görüntü **ölçülemedi**; sıfır olarak sunulmaz.
Lamba/genel kırık parça metrikleri yalnızca kendi kaynaklarının tam sınıf
anotasyonlarında teşhis amacıyla verilir; farklı kohortlar doğrudan kıyaslanmaz.

## Yerel kaynak tüketimi

i5-12450H, Windows, RTX 4050 Laptop GPU. Her model/cihaz ayrı process;
aynı 24 önceden decode edilmiş fotoğraf, 10 warmup, 120 ölçüm, 4 Torch thread.
İlk backend yüklemesinin thread sayısını değiştirmesi ölçüm kodunda ele alınır.
Wall süre preprocess + inference + NMS + Python API; disk/ağ/backend hariç.

| Model | Dosya MiB | CPU p50/p95 ms | GPU p50/p95 ms | CPU peak RAM MiB |
|---|---:|---|---|---:|
| CarDD | 5.210 | 137.80 / 202.80 | 36.68 / 55.64 | 803.6 |
| RF Nano | 5.209 | 144.06 / 176.75 | 33.49 / 43.13 | 796.7 |

RAM Python/framework dahil process working set'tir. Forward-only süreler,
ham latency örnekleri ve RSS tabanı JSON dosyalarında ayrıca bulunur.
**Bunlar Railway production performansı değildir.** Ardışık yerel ölçüm,
donanım güç/ısı durumu ve runtime farkları üretime genellenemez.

## Çalıştırma ve çıktılar

`ai-service` içinden, mevcut venv ile:

```powershell
.\venv\Scripts\python.exe scripts/compare_cardd_roboflow_nano.py audit
.\venv\Scripts\python.exe scripts/compare_cardd_roboflow_nano.py review-sheets
# audit hash'ine bağlı açık retain_exploratory/exclude kararlarını
# cohort_review.json içine kaydet; görüntü kimliği ve gerekçe zorunludur.
.\venv\Scripts\python.exe scripts/compare_cardd_roboflow_nano.py evaluate --device 0
.\venv\Scripts\python.exe scripts/compare_cardd_roboflow_nano.py benchmark
.\venv\Scripts\python.exe scripts/compare_cardd_roboflow_nano.py report
.\venv\Scripts\python.exe scripts/compare_cardd_roboflow_nano.py verify
.\venv\Scripts\python.exe -m unittest discover -s tests
```

Tekrar audit için yeni `--output` dizini kullanılır; mevcut audit ezilmez.
Tüm fazlarda aynı output yolu kullanılmalıdır. Eşleştirme, sınıf ID'leri,
AP sınır durumları, sızıntı bileşenleri ve görsel inceleme bağları otomatik
testlerle doğrulanır. Bu çalışmada 164 Python testi geçti.

Yerel çıktı dizini: `ai-service/evaluation-runs/cardd-vs-roboflow-nano/`.
Mevcut `.gitignore` gereği büyük sonuçlar ve görseller Git dışında kalır:

- `comparison.json`, `per_class_comparison.csv`, `comparison_report.md`.
- Sınıf grafikleri, confusion matrix, yerel latency grafiği ve 12 yan yana örnek.
- `audit.json`: bütün görüntü/etiket hash'leri, sızıntı çiftleri, ilk dışlamalar.
- `cohort_review.json` / `cohort.json`: görsel kararlar ve nihai kohort.
- `predictions.json` / `metrics.json`: native tahminler, doğru/yanlış eşleşmeler,
  kaynak bazlı sonuçlar, AP tabanı ve çalışma eşiği sonuçları, provenance.
- `benchmark_*.json`: ölçüm kapsamı, donanım, thread sayısı ve ham örnekler.

Değişim kararı için bağımsız araç/oturum gruplarıyla yeni dış test verisi,
ortak ve eksiksiz anotasyonlar, yeterli hasarsız örnek ve CRACK desteği gerekir.
Bu çalışma eğitim, production değişikliği, master merge veya deployment yapmaz.
