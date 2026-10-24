# EksperSiz — birleşik HITL / YOLOX-Tiny

Bu belge ilk sıfırdan eğitim baseline'ını kaydeder. RF-DETR transfer adayları,
ayrı model CPU adaptörü ve lisans incelemesi [yeni deney belgesindedir](TRANSFER_LEARNING.md).

## Durum ve kullanım sınırı

24 Ekim 2026. Sistem tek fotoğrafta hasar ve parça çıktısı veren, tek checkpoint ve
tek ONNX grafiği kullanan iki görevli altyapıya geçirilmiştir. Yerel eğitim ve
değerlendirme sonuçları ayrı raporlanır. Bu belge üretim aktivasyonu değildir.
`DAMAGE_ANALYSIS_ENABLED` varsayılan olarak kapalıdır; export işlemi ayrıca
`production_approved: false` üretir. İki koşul sağlanmadan backend kredi ayırmaz.
Bu görevde canlı Railway dağıtımı veya Git işlemi yapılmaz.

## Veri ve gerçek sınıflar

Klasör adları içerikle ters düşmektedir. `Car damages dataset` 998 parça etiketli,
`Car parts dataset` 814 hasar etiketli kaynak görüntü içerir. Görev, `meta.json`
sınıfları ve her nesnenin `classTitle/classId` eşleşmesinden doğrulanır.

Hasar sınıfları: **Broken part, Corrosion, Cracked, Dent, Flaking, Missing part,
Paint chip, Scratch**. Parça sınıfları: **Back-bumper, Back-door, Back-wheel,
Back-window, Back-windshield, Fender, Front-bumper, Front-door, Front-wheel,
Front-window, Grille, Headlight, Hood, License-plate, Mirror, Quarter-panel,
Rocker-panel, Roof, Tail-light, Trunk, Windshield**.

Ham veride 1.812 görüntü ve 24.851 poligon vardır. `Car damages 992.jpg.json`
dosyasında iki sıfır genişlik/yükseklikli Scratch poligonu bulunmuştur. Bu hasar
görüntüsünün 32 nesnesi birlikte karantinaya alınmıştır; kısmen etiketli bir
görüntüden hatalı negatif üretilmez. Varsayılan dönüşüm bu hatada durur;
`--quarantine-invalid` açıkça verilirse raporlayarak dışlar. Ham veri değiştirilmez.

İki kaynak arasında piksel olarak aynı 441 görüntü vardır. Bunların tamamlayıcı
hasar/parça anotasyonları aynı kanonik görüntü altında birleşir. Kullanılabilir
veri: **1.370 özgün görüntü, 24.819 poligon, 441 iki görevli görüntü**. Diğer
görüntülerde yalnızca mevcut görevin etiketi geçerlidir. Tamamen aynı piksel
görüntüleri ve dHash uzaklığı en fazla 4 olan yakın görüntüler grup düzeyinde
ayrılır. Sabit seed 2026 ile train/validation/test: **1.095 / 137 / 138**.
Araç veya çekim oturumu kimliği bulunmadığından bütün ilişkili araçların ayrıldığı
iddia edilmez; bilinen kopyalar ayrılmıştır. Test verisi model/çözünürlük seçimi
için kullanılmaz.

Orijinal poligonlar, delikler korunarak COCO RLE segmentasyonu ve gerçek piksel
koordinatlarından bbox olarak saklanır. `masks_human` ve `masks_machine` ayrı
eğitim örnekleri yapılmaz. Bu adlar tek başına insan/AI üretimi kanıtı değildir;
JSON nesnelerindeki labeler bilgisi ve yayıncı açıklaması esas alınır. Raster
maskeler doğrulanır; insan görselleştirme çıktısının boyutu özgün resimden farklı
olabilir. Sınıf bazlı ham ve kullanılabilir sayılar [tabloda](HITL_CLASS_COUNTS.md),
ayrıntılar [denetim JSON'unda](HITL_DATASET_AUDIT.json) bulunur.

## Mimari ve kısmi etiketler

Resmî Megvii YOLOX'un `6ddff4824372906469a7fae2dc3206c7aa4bbaee`
revizyonundaki Tiny ayarları kullanılır: CSPDarknet + PAFPN, depth 0.33,
width 0.375; paylaşılan üç ölçekli özellikler, 8 hasar ve 21 parça sınıflı iki
ayrı YOLOXHead. Omurga fotoğraf başına bir kez çalışır. Global sınıf ID'si ile
head içi `task_index` farklı alanlardır; katalog bu farkı açıkça korur.

`task_mask[B,2]` eğitimde her head'in yalnızca ilgili görevi etiketli görüntülerini
seçer. Etiketsiz head çağrılmaz; o head'e objectness negatifleri, gradient veya BN
güncellemesi gitmez. İki görevli piksel eşleri iki head'i birlikte eğitir.
Batch örnekleme görev ve nadir sınıf dengesini gözetir. Mosaic/mixup kullanılmaz;
yalnızca eğitimde yatay çevirme ve sınırlı parlaklık artırımı uygulanır.

SGD + momentum/Nesterov, warmup/cosine learning rate, gradient accumulation,
gradient clipping, validation tabanlı early stopping, güvenli checkpoint yükleme,
resume ve RNG kayıtları bulunur. Bbox log boyutları eğitim/çıkarımda aynı
[-10,10] aralığında sınırlandırılır; exp taşması gizlice geçiştirilmez.
Early stopping `--patience` sayıda validation kontrolüne göre işler.

Hazır ağırlık kullanılmaz. Kullanıcının tercihi doğrultusunda bu koşu sıfırdan
eğitilir. Checkpoint'ler ve büyük çıktılar kaynak deposuna eklenmez.

## Tek analiz sözleşmesi

Kanonik katalog: `ai-service/app/vision/classes.json`. Kaynak isimleri ve global
ID'ler korunur; API `code` alanı sadece isimlerin büyük harf/alt çizgi biçimidir.
Örneğin `Cracked` → `CRACKED`, `Back-bumper` → `BACK_BUMPER`.
Bunlar eski `CRACK` veya `REAR_BUMPER` sınıflarına zorla çevrilmez.

Python, Java `VisionClassCatalog` ve Flutter `VisionClassCatalog` aynı katalogdan
üretilir. Java enum'ları eski değerleri de okur. V17 yalnızca yeni değerler ve
kanıt/model sürümü alanları ekler; eski migration'lar ve kayıtlar değiştirilmez.
Ham model kanıtı, orijinal isimler ve iki head'in tespitleri analysis_payload içinde
saklanır. Geçmiş raporlar kendi kayıtlı sonuçlarından üretilir.

API `schemaVersion: hitl-v1`, `modelVersion`, `analysisOutcome`, gerçek güven
skorları, bbox'lar, hasar ve parça tespitlerini döndürür. Güven, head'in
objectness × sınıf olasılığıdır. NMS sınıf bazlıdır. Piksel koordinatları orijinal
fotoğrafa geri dönüştürülür. Belirsiz eşleştirme UNKNOWN kalır; FRONT/REAR
tespitin ismini değiştirmez, çelişkili eşleştirmeyi reddedebilir.

Model hasar bulamazsa **INCONCLUSIVE** döner; bu, NO_VISIBLE_DAMAGE değildir.
Backend bunu tamamlanmış ücretli analiz saymaz ve rezervasyonu bırakır.
Şiddet, çatlak derinliği ve parça değişimi gereksinimi bu etiketlerden öğrenilemez:
şiddet UNKNOWN, değişim gereksinimi null, öneri PROFESSIONAL_INSPECTION olur.
Gemini yeni hasar veya kesin işlem uyduramaz. Mevcut fiyat/web mekanizması, bu
durumda onarım yerine fiziksel inceleme maliyeti tahminiyle sınırlanır; mobil/PDF
başlıkları bu ayrımı gösterir. Geçmiş onarım fiyatları korunur.

## Çalıştırma

Komutlar `ai-service` dizininden çalıştırılır. Önce uygun PyTorch CPU/CUDA
kurulumu yapılır; bu makinede mevcut PyTorch 2.13.0 + CUDA 13.0 kullanılmıştır.

```bash
python -m pip install -r requirements-training.txt
python -m ml.dataset --raw datasets/raw --output datasets/hitl-coco --quarantine-invalid
python scripts/generate_vision_contract.py
python -m ml.report_dataset
python -m ml.train --data datasets/hitl-coco --output training-runs/smoke --epochs 2 --smoke 8 --batch 4 --eval-every 1
python -m ml.train --data datasets/hitl-coco --output training-runs/hitl-tiny-416 --epochs 50 --batch 8 --size 416 --eval-every 5
# Kesilen aynı koşu:
python -m ml.train --data datasets/hitl-coco --output training-runs/hitl-tiny-416 --resume training-runs/hitl-tiny-416/last.pth --epochs 50 --batch 8 --size 416 --eval-every 5
python -m ml.evaluate --checkpoint training-runs/hitl-tiny-416/best.pth --data datasets/hitl-coco/val.json --size 416 --output evaluation-runs/val-416.json
python -m ml.evaluate --checkpoint training-runs/hitl-tiny-416/best.pth --data datasets/hitl-coco/val.json --size 640 --output evaluation-runs/val-640.json
python -m ml.export --checkpoint training-runs/hitl-tiny-416/best.pth --output models/hitl-416 --size 416 --image "datasets/raw/Car damages dataset/File1/img/Car damages 100.png"
python -m ml.benchmark --bundle models/hitl-416 --image "datasets/raw/Car damages dataset/File1/img/Car damages 100.png" --output evaluation-runs/onnx-416.json
python -m unittest discover -s tests -v
```

416/640 karşılaştırması aynı checkpoint'in farklı giriş çözünürlüklerindeki
validation değerlendirmesidir; iki ayrı tam eğitim deneyi olduğu iddia edilmez.
Çözünürlük validation ile seçilir; bağımsız test o seçimden sonra çalıştırılır.
COCO mAP50/mAP50:95 yalnızca o görev için etiketli görüntülerde hesaplanır.
Precision/recall/F1 ve confusion matrix ayrıca 0.25 güven / 0.5 IoU çalışma
noktasını raporlar. Sınıf başına AP ve FP/FN ham değerlendirme JSON'larında bulunur.
441 çift görevli görüntüde iki tespit görevi değerlendirilebilir; fakat gerçek
hasar nesnesi→parça nesnesi ilişki etiketleri yoktur. Eşleştirme doğruluğu ayrı
insan incelemesi olmadan ölçülmüş kabul edilmez.

## ONNX, Docker ve üretim kapısı

ONNX export sabit batch=1 ve 416 veya 640 girişle iki decoded head üretir.
Exporter gerçek bir fotoğrafta iki head'in tüm ham çıktılarını PyTorch ile
karşılaştırır; başarısızsa bundle onaylanmaz. Runtime sadece ONNX Runtime ve
NumPy/Pillow kullanır; `ml/`, COCO evaluator ve ONNX exporter Docker'a alınmaz.
PyTorch üretimde mevcut E5/RAG metin embedding'i için korunur.

Model bundle'ı runtime'a `DAMAGE_MODEL_BUNDLE` ile dışarıdan bağlanır. Kontrol
kapalıysa servis kimliği doğrulandıktan sonra fotoğraf gövdesi okunmadan 503
döner. Açıkken de bundle onayı, model/katalog hash'leri, sınıf ve çıktı imzaları
kontrol edilir. Oturum lazy yüklenir; inference seri, fotoğraf işleri sınırlıdır.
Backend ayrıca readiness'i kredi rezervasyonundan önce doğrular. Flutter derleme
bayrağı da varsayılan kapalıdır. Hiçbir eğitim veya export komutu bunları açmaz.

Üretim onayı öncesinde: bağımsız hasar recall'ı ve sınıf bazlı sınırlar, temiz/
araç olmayan negatif fotoğraflar, eşleştirme uzman incelemesi, fotoğraf kalite ve
confidence kalibrasyonu, cihaz uçtan uca akışı ve gerçek Railway kaynak limiti
altında yük testi gereklidir. Düşük hasar recall'ı varsa özellik kapalı kalır.

## Lisans kanıtı

- HITL yayıncısı veri setini [CC0 1.0](https://humansintheloop.org/resources/datasets/car-parts-and-car-damages-dataset/)
  altında yayımlar.
- Resmî [YOLOX kaynak lisansı Apache-2.0](https://github.com/Megvii-BaseDetection/YOLOX/blob/6ddff4824372906469a7fae2dc3206c7aa4bbaee/LICENSE).
  Kaynak lisansı ve yapılan değişiklik bildirimi vendor dizininde korunur.
- Hazır ağırlıkların ayrı lisansı doğrulanmadığından **hiçbiri indirilmez veya
  kullanılmaz**. Resmî projedeki [ağırlık lisansı sorusu](https://github.com/Megvii-BaseDetection/YOLOX/issues/1865)
  ayrı bir kanıt eksikliğini gösterir; kod lisansından ağırlık lisansı çıkarılmaz.
- ONNX Apache-2.0, ONNX Runtime MIT; yeni paketlerin gerçek sürüm/lisans/notice
  envanteri [buradadır](ML_DEPENDENCY_LICENSES.json). Binary dağıtımında bu
  paketlerin kendi notice/üçüncü taraf lisans dosyaları da korunmalıdır.

## Doğrulama ve sonuçlar

Gerçek eğitim/evaluation sayıları `HITL_RESULTS.json` ve `HITL_RESULTS.md` içinde
raporlanır. Smoke sonuçları doğruluk kanıtı değildir. Docker daemon, ücretli dış
servisler veya fiziksel cihazlar çalıştırılamadıysa bu sınırlamalar sonuçlara
açıkça yazılır. Birim testlerinin geçmesi üretim model onayı değildir.
