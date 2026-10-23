# Roboflow 11 sınıflı YOLO11 detection deneyi

Bu çalışma yalnızca deney hazırlığıdır. GPU eğitimi, model değerlendirme koşusu,
production inference bağlantısı, deployment veya master merge yapılmadı.
Branch: `feature/roboflow-damage-detection-experiment`; başlangıç noktası önceki
otomobil güvenilirliği çalışmasının `75cd2ca` commit'idir.

## Kaynak ve format

İstenen `ai-service/datasets/raw/roboflow_car_damages_segmentation/` yolu yerelde yoktu.
Bulunan kaynak:

```text
ai-service/datasets/raw/cardd/roboflow_car_damages_segmentation/
```

Kaynak taşınmadı/değiştirilmedi. Import script'i önce istenen konuma, yoksa bulunan
bu konuma bakar; `--source` ile açık konum da verilebilir. Kullanılan kesin konum,
her kaynak dosyasının SHA-256 değeri ve toplam manifest fingerprint'i rapora yazılır.

Export README'si 1.811 görüntü, YOLOv11 formatı ve augmentation uygulanmadığını
bildiriyor. Dosyaların gerçek içeriği değişken uzunluklu **instance segmentation
poligonlarıdır** (satır başına sınıf ID + en az üç normalize XY noktası).
YOLOv8/v11 export adı tek başına bbox formatı olduğunu göstermez.
Kaynak train/valid/test dağılımı: **1268 / 362 / 181**.

YAML `../train/images`, `../valid/images`, `../test/images` yazıyor. YAML dizinine
göre doğrudan çözmek komşu CarDD dizinine kaçacağından importer yalnızca export'un
kendi `train/images`, `valid/images`, `test/images` klasörlerini kabul eder.
Başka path biçimlerini reddeder; bu düzeltmeyi `split_resolution` alanına kaydeder.

## Bağımsız sınıf sözleşmesi ve gerçek dağılım

Mapping: `ai-service/config/roboflow_damage_v3.yaml`. İlk deneyde 11 kaynak sınıfı
birebir korunur. ID'ler **CarDD ID'leri değildir**; production enum/mapping'i değildir.
Tablodaki sayılar son türetilmiş veri setindeki **bbox instance** sayılarıdır.

| ID | Kaynak adı | Deney sınıfı | Train | Val | Test | Toplam |
|---|---|---|---:|---:|---:|---:|
| 0 | Broken part | BROKEN_PART | 233 | 40 | 31 | 304 |
| 1 | Cracked | CRACK | 159 | 25 | 21 | 205 |
| 2 | Dent | DENT | 691 | 168 | 78 | 937 |
| 3 | Missing part | MISSING_PART | 56 | 11 | 9 | 76 |
| 4 | Paint damage | PAINT_DAMAGE | 459 | 79 | 87 | 625 |
| 5 | Scratch | SCRATCH | 934 | 187 | 204 | 1325 |
| 6 | broken_lamp | BROKEN_LAMP | 118 | 21 | 22 | 161 |
| 7 | broken_mirror | BROKEN_MIRROR | 62 | 20 | 6 | 88 |
| 8 | cracked_glass | CRACKED_GLASS | 118 | 33 | 15 | 166 |
| 9 | dent_hail | DENT_HAIL | 18 | 8 | 0 | 26 |
| 10 | tire_flat | TIRE_FLAT | 59 | 18 | 8 | 85 |
| | | **Toplam** | **2907** | **610** | **481** | **3998** |

Kaynakta `BROKEN_GLASS` sınıfı **yoktur**. `cracked_glass` buna otomatik çevrilmedi.
İncelenen cam örneğinde parçalanmış cam da görünüyor; kaynak anotasyon politikasının
çatlak/kırık cam sınırlarını ayrıca netleştirmek gerekir. Kaynaktaki genel
`BROKEN_PART`, CarDD modelinin lamba kırığından gelen aynı isimli sınıfıyla eş anlamlı
varsayılmaz. Lamba, ayna ve genel parça sınıfları birleştirilmez.

## Kalite kontrol sonucu

| Split | Kaynak görüntü | Geçerli türetilmiş görüntü | Karantinaya alınan |
|---|---:|---:|---:|
| train | 1268 | 1222 | 46 |
| val | 362 | 328 | 34 |
| test | 181 | 170 | 11 |
| Toplam | 1811 | **1720** | **91** |

- Kaynakta 4180 anotasyon satırı vardı. Geometri kontrolünde 8 görüntüde kendini
  kesen poligon bulundu (6 train, 2 val). Bu görüntülerin **bütün anotasyonlarıyla
  birlikte** dışlanmasıyla 13 anotasyon aktarılmadı. Kaynakta düzeltme yapılmadı.
- Görüntü/etiket eşi eksikliği, orphan label veya okunamayan görüntü bulunmadı.
- Kaynak split'leri arasında **42 exact duplicate çift / 83 farklı görüntü** vardı.
  Dosya hash'i veya çözülmüş RGB piksel+boyut hash'i eşitliğiyle doğrulandı.
  Her iki taraftaki tüm görüntüler türetilmiş setten karantinaya alındı; bir split
  seçilerek diğerine taşınmadı. Böylece son sette exact cross-split tekrar kalmadı.
- Kaynakta ayrıca 28 cross-split near-duplicate adayı bulundu. Geometri ve exact
  karantinasından sonra **22 çift hâlâ iki tarafta da aktarılan görüntülerden oluşuyor**.
  Bunlar eğitimi engelliyor. DCT pHash (63 bit), Hamming <=6 ve boy oranı toleransı
  kullanılır; adaylık tek başına aynı sahne kanıtı değildir. Büyük crop, farklı açı
  veya aynı aracın farklı kareleri kaçabilir; bu yöntem sızıntı olmadığını kanıtlamaz.
- Aynı split içinde son sette 19 exact çift ve 25 benzerlik adayı kalıyor. Bunlar
  cross-split sızıntı değildir fakat örnek ağırlıklarını etkileyebilir. Bilinçli
  inceleme olmadan yeniden örnekleme yapılmadı.
- 17 train + 1 test görüntüsünün etiketi boş. Bunlar kaynağın olası negatifleri
  olarak korunur; eksik etiket dosyaları negatif kabul edilmez. **18 negatifin
  tamamı** görsel inceleme örneklerine dahildir; hasar atlanmadığı doğrulanmalıdır.
- Train'de instance dengesizliği `934 / 18 = 51.89`. `DENT_HAIL` test desteği 0;
  bu sınıfın test AP'si hesaplanabilir değildir. Başka split'ten test'e görüntü
  taşınmadı. Aynada 6, lastikte 8 test instance'ı sonucu çok oynak yapabilir.

Source ve output dosya manifest'leri, görüntü bazında sınıf ID'leri/hatalar,
source/output instance dağılımları, sınıf başına görüntü sayıları, benzerlik çiftleri,
mapping ve araç sürümleri `import-report.json` içindedir. Orijinal dosyalar import
öncesi/sonrası hash karşılaştırmasıyla korunur. Hatalı bir poligonun yalnızca
kendisini atıp kalan etiketleri kullanma yolu yoktur.

## Yerel çıktılar

```text
ai-service/datasets/vehicle_damage_detection_v3_rf/
  images/{train,val,test}/
  labels/{train,val,test}/          # normalize cx cy width height, 10 ondalık
  source-segmentation/{train,val,test}/ # aktarılan görüntülerin özgün poligon etiketleri
  source-metadata/                 # kaynak YAML, README'ler, mapping kopyası
  review-samples/                  # 45 anotasyon/negatif örneği + 70 çift görseli
  data.yaml
  import-report.json
  review.json                     # bilinçli olarak onaysız
  README.md
```

Kırmızı kutu dönüştürülmüş bbox, camgöbeği çizgi kaynak poligondur.
`cx=(min(x)+max(x))/2`, `cy=(min(y)+max(y))/2`, `w=max(x)-min(x)`,
`h=max(y)-min(y)`; görüntü boyutu değiştirilmez. Görseller yalnızca inceleme
kopyalarında küçültülür. Input poligonlarında NaN/Inf, sınır dışı koordinat,
geçersiz ID, üçten az nokta, sıfır alan, tekrarlı vertex ve kesişme kontrol edilir.
Kapanış noktasının başa eşit olması kabul edilir. Koordinatlar sessizce kırpılmaz.

İlk import kopyası `target/roboflow-v3-initial-import/` altında yerel audit için
korundu; güncel eğitim girdisi değildir. Güncel veri seti yukarıdaki V3 dizinidir.
Kaynak tüm segmentasyon verisi raw konumunda da aynen durur. Gelecekteki segmentation
deneyi için ayrı image/label ağacı oluşturulmalıdır; detection label klasörüne
poligonlar karıştırılmamalıdır.

Görsel incelemede lamba, cam, iki olası negatif ve bir cross-split yakın kopya
örneği açıldı. Yakın kopya örneğinde aynı hasarın farklı işlenmiş görüntüleri görüldü.
Bu sınırlı kontrol, tüm veri setinin anlamsal etiket doğrulaması sayılmaz. `review.json`
otomatik onaylanmadı; 45 örnek ve kalan 22 benzer çift için inceleme hâlâ gerekir.

## Eğitim öncesi zorunlu kontrol

1. `review-samples/` ve rapordaki karantina nedenlerini incele. Özellikle sınıf
   sınırları, görünür fakat etiketlenmemiş hasar, çoklu araçlar ve bütün negatifler
   kontrol edilmeli. Test görselleri yalnızca veri kalitesi için görülür; model
   seçimi/threshold ayarı için kullanılmaz.
2. Kalan cross-split near çiftleri incele. Gerçekten farklıysa `review.json` içindeki
   çift ID'sine `{"decision":"distinct","reason":"somut görsel gerekçe"}` yazılır.
   Aynı araç/sahne/kopyaysa “distinct” denmez; ilgili grubun **tüm görüntüleri**
   bir quarantine JSON listesine yazılarak **yeni hedefe** tekrar import edilir.
   Birden fazla çiftle bağlı görüntülerin tüm grubu birlikte değerlendirilmelidir.
3. Gerekirse bozuk/müpheli anotasyon taşıyan başka görüntüler de aynı listeyle
   bütünüyle dışlanır. İlk deneyde sınıf silme/birleştirme mapping tarafından reddedilir.
   Hiçbir sınıfın train desteği sıfıra düşmemelidir.
4. Onayı veren kişi `reviewer`, `reviewed_at`, gereken boolean alanları ve
   `reviewed_samples` listesini doldurur. Rapor hash'i aynı olmalıdır. Kaynak kökenini
   araştırma kullanımı için değerlendirmek ticari kullanım onayı değildir.
5. Script hem veri setini hem inceleme görsellerini hash ile kontrol eder. Dosya
   veya üyelik değiştiyse eski onay geçmez. `--check-only` geçmeden model yüklenmez.

## Komutlar — henüz çalıştırılacak eğitim yok

`ai-service` dizininden (Windows örneği):

```powershell
# Yeniden import: mevcut hedefi ASLA ezmez; yeni hedef adı seçin.
.\venv\Scripts\python.exe scripts/import_roboflow_damage_dataset.py `
  --source datasets/raw/cardd/roboflow_car_damages_segmentation `
  --target datasets/vehicle_damage_detection_v3_rf_reviewed `
  --quarantine-list path/to/reviewed-quarantine.json

# JSON örneği: ["train/images/example.jpg", "test/images/duplicate.jpg"]
# Yeni import yeni review.json ve yeni rapor hash'i oluşturur.

.\venv\Scripts\python.exe scripts/train_roboflow_damage_model.py `
  --data datasets/vehicle_damage_detection_v3_rf/data.yaml --check-only

# Aşağıdakiler yalnızca kalite + görsel inceleme engelleri kaldırıldıktan sonra:
.\venv\Scripts\python.exe scripts/train_roboflow_damage_model.py `
  --data datasets/vehicle_damage_detection_v3_rf_reviewed/data.yaml `
  --variant n --weights yolo11n.pt --name rf11-n-seed42 `
  --epochs 100 --patience 20 --batch 8 --imgsz 640 --seed 42 --device 0

.\venv\Scripts\python.exe scripts/train_roboflow_damage_model.py `
  --data datasets/vehicle_damage_detection_v3_rf_reviewed/data.yaml `
  --variant s --weights yolo11s.pt --name rf11-s-seed42 `
  --epochs 100 --patience 20 --batch 8 --imgsz 640 --seed 42 --device 0
```

`yolo11n.pt` mevcut ve yalnızca okunur. YOLO11s ağırlığı henüz yok; güvenilir yerel
checkpoint ayrıca sağlanmalıdır. Script kendisi ağırlık indirmez. İki varyantın
checkpoint mimarisi/scale/task'ı ve 80 sınıflı başlangıç başlığı kontrol edilir;
CarDD 5 sınıflı model başlangıç checkpoint'i olarak kabul edilmez. `cls_remap=False`
ile farklı sınıf başlıkları arasında otomatik isim aktarımı kapatılır.

Yerel ortamda kontrol anında PyTorch `2.13.0+cu130`, CUDA kullanılabilir ve
Ultralytics `8.4.106` vardı. Bu kontrol eğitim başlatmadı. Eğitim ortamı paket
sürümleri, CUDA/cuDNN/cihaz, seed, deterministic, git commit/dirty durumu, script,
başlangıç checkpoint, dataset raporu ve inceleme hash'leri `experiment.json` içine
yazılır. Donanım/sürüm değişince bit düzeyinde aynı sonuç garantisi verilmez.

Çıktı: `training-runs/roboflow-v3/<name>/`. `args.yaml`, `results.csv` (train loss,
val P/R/mAP ve val loss), öğrenme eğrileri, `weights/best.pt`, `last.pt`, 10 epoch
aralıklarla checkpoint ve dosya hash'leri kaydedilir. Test split'i eğitimde
kullanılmaz. Best/early stopping mevcut kurulu sürümde validation mAP50-95 fitness'ına
göredir. İsim çakışırsa çalışma ezilmez. Otomatik resume yok; farklı veri/onayla eski
checkpoint'e yanlışlıkla devam edilmez. CPU denemesi istenirse `--device cpu` kullanılabilir;
bu aşamada CPU veya GPU eğitimi yapılmadı.

## Evaluation

```powershell
.\venv\Scripts\python.exe scripts/evaluate_roboflow_damage_model.py `
  --data datasets/vehicle_damage_detection_v3_rf_reviewed/data.yaml `
  --weights training-runs/roboflow-v3/rf11-n-seed42/weights/best.pt `
  --name rf11-n-seed42-test --split test --device 0 --imgsz 640 --batch 8 `
  --conf 0.001 --iou 0.60
```

`evaluation-runs/roboflow-v3/<name>/evaluation.json`: aggregate Precision, Recall,
mAP50, mAP50-95; sınıf bazında P/R/AP50/AP50-95 ve GT instance desteği; ham
confusion matrix (satır prediction, sütun GT, background dahil). PNG normal/normalize
matrisler ve PR eğrileri Ultralytics çıktılarındadır. Checkpoint, dataset, review,
ortam ve threshold'lar raporda sabitlenir.

`BROKEN_PART`, `BROKEN_LAMP`, `BROKEN_MIRROR`, `CRACKED_GLASS` ayrı raporlanır.
İstenen `BROKEN_GLASS` alanı `NOT_PRESENT_IN_SOURCE_TAXONOMY` olarak belirtilir.
GT'si olmayan `DENT_HAIL` için AP `null` olur; Ultralytics'in `maps` alanının
bulunmayan sınıfa genel ortalama koyma davranışı kullanılmaz. Aggregate AP, destekli
sınıflar üzerindeki değerdir; 11 sınıfın hepsinde ölçüm varmış gibi sunulmaz.

P/R özetleri max-F1 confidence noktasındadır; bunlar seçilen işletim eşiğindeki
P/R değildir. `conf=0.001`, AP/PR değerlendirme tabanıdır; IoU=0.60 NMS eşiğidir,
AP50'nin IoU=0.50 eşleştirme kriteriyle karıştırılmaz. İstenirse validation ile
seçilmiş işletim eşiğinde ayrı matris koşusu farklı isimle kaydedilir. Test seti
threshold ayarı veya varyant/seed seçimi için kullanılmaz. Önce n/s aynı seed/ayarlar,
sonra en az üç seed ile validation kararlılığı; son seçimin test değerlendirmesi.
Bu çalışma hiçbir gerçek model metriği üretmedi.

## CarDD ile adil karşılaştırma protokolü

- RF-11 mAP ile CarDD-5 mAP doğrudan karşılaştırılmaz. Mevcut production evaluator
  genişletilmedi; RF evaluator CarDD checkpoint'ini sınıf sözleşmesinden reddeder.
- İki modelin de eğitim/validation verileriyle çakışmayan ayrı, dondurulmuş bir
  değerlendirme kümesi gerekir. RF içinde `000xxx` gibi dosyalar var; CarDD kökeni
  veya önceki modelin eğitim görüntüleriyle örtüşme bu çalışmada tam audit edilmedi.
  Kaynaklar arası exact/near ve aynı araç/sahne kontrolü zorunludur.
- Ortak adaylar `SCRATCH`, `DENT`, `CRACK`; isim eşitliği yeterli değildir. Etiket
  tanımları, instance ayrımı, kutu kapsamı ve exhaustiveness insan tarafından
  uyumlu bulunmalıdır. Ortak olmayan hasarı taşıyan görüntü tümüyle dışlanır veya
  açıkça desteklenen ignore-region evaluator'u gerekir; etiket satırı silmek yetmez.
- CarDD `BROKEN_PART` = lamp broken; RF `BROKEN_PART` genel, RF `BROKEN_LAMP` ayrı.
  Bunların ID/isimleri otomatik birleştirilmez. Cam sınıfları da otomatik eşitlenmez.
- Aynı görüntüler, ortak etiketler, resize/imgsz, confidence tabanı, NMS IoU,
  max_det ve değerlendirme kodu kullanılır; özgün checkpoint'ler değişmeden
  değerlendirme adaptörüyle isim/ID remap'i açık versiyonlanır.
- Hasar detector sonucu ile araç kapsamı/parça eşleştirmesi içeren ürün uçtan uca
  sonucu ayrı ölçülür. Bu aşama yeni modele production desteği verdiği anlamına gelmez.

## Lisans ve kaynak sınırı

Export YAML/README `CC BY 4.0`, workspace `gorkem-ertas`, proje
`car-damages-segmentation-fedhl`, version 1 bildiriyor. Bu export beyanıdır;
özgün fotoğrafların hak sahipliği, yeniden paylaşım izni ve anotasyon kökeni doğrulanmadı.
Çok sayıda `istockphoto` adlı dosya ve web kaynaklı ad var; dosya adı tek başına
hak ihlali kanıtı veya kullanım izni değildir. Roboflow sayfası web aracıyla
erişilebilir değildi. Ticari kullanıma uygunluk onayı verilmedi. Eğitim öncesi
araştırma kullanımının da veri kökeni açısından incelenmesi gerekir.

Kaynaklar: [Roboflow export'un işaret ettiği sayfa](https://universe.roboflow.com/gorkem-ertas/car-damages-segmentation-fedhl/dataset/1),
[Ultralytics polygon formatı](https://docs.ultralytics.com/datasets/segment/),
[Ultralytics validation metrikleri](https://docs.ultralytics.com/modes/val/).
Uygulama ayrıca kurulu `ultralytics==8.4.106` kaynak koduyla kontrol edildi.

## Korunanlar ve testler

`train_damage_model.py`, `experiments/config.py`, CarDD V2 dosyaları,
production ağırlıkları, `model_contract.py`, Java Backend ve Flutter değiştirilmedi.
Mevcut production validator RF-11 sınıflarını hâlâ reddediyor. Veri seti, bütün
görseller/etiketler, review çıktıları ve ağırlıklar Git dışında kalır. Script'ler,
mapping, otomatik testler ve bu runbook Git'e alınabilir.

Otomatik testler: polygon->bbox geometri, geçersiz poligon, bütün görüntü karantinası,
eksik dosya, ID/mapping ayrımı, source hash/split koruma, exact ve near leakage,
görsel onay/fingerprint engeli, aynı içerikle tekrar üretim, metriklerde olmayan
sınıfın AP'si ve eğitim parametreleri/provenance (mock model; GPU kullanılmaz).
`python -m unittest discover -s tests`: **150 test geçti** (12 yeni deney testi
dahil). Eğitim ve evaluation akışı sahte modelle test edildi; gerçek GPU eğitimi
ve gerçek model değerlendirmesi yapılmadı. Mevcut veri setinde `--check-only`,
görsel inceleme onayı eksik olduğu için beklendiği gibi engellendi. Ayrıntılar
yerel `target/roboflow-*` loglarındadır. Backend ve Flutter dosyaları değişmediği
için bu deney kapsamında bu iki uygulamanın testleri yeniden çalıştırılmadı.
