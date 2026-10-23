# Otomobil analizi: kapsam, model sözleşmesi ve belirsizlik

İnceleme: 23 Ekim 2026. Branch: `feature/car-analysis-reliability`.
Bu çalışma model eğitimi, yeni veri seti, yeni ağırlık, deployment veya master merge içermez.

## Bulgular ve değişiklikler

Önceki akış genel YOLO'nun `car`, `truck`, `bus`, `motorcycle` sınıflarını aynı kabul ediyordu.
Otomobil bulunmadığında tek bir tanınan parça yeterliydi; `purpose=damage` ön kontrolü
araç kanıtına hiç bakmıyordu. Eski iki fotoğraflı akış, kapsam kontrolünden önce temiz
sonuç döndürebiliyor ve yalnızca hasar sınıfı aynı diye farklı fotoğraflar arasında parça aktarıyordu.
Ön/arka seçimi tespit edilen parçayı karşı taraftaki parçaya çevirebiliyordu.
Şiddet parça sayısından; onarım/değişim hasar adından üretiliyordu. Bunlar eğitilmiş çıktılar değildi.

Üç model korunur: genel araç tespiti, hasar tespiti ve parça tespiti. Hasar ve parça modelleri ayrıdır.
Servis mevcut dosyaları yüklemeden SHA-256 doğrular; hasar/parça checkpoint sınıf sıralarını
`ai-service/app/model_contract.py` ile karşılaştırır. Uyumsuz artifact teknik hatadır;
sessizce başka model kullanılmaz. Docker zaten `app` klasörünü ve bu üç ağırlığı kopyalar.

## Doğrulanan mevcut ağırlıklar

| Rol | Dosya | Checkpoint tarihi | Eğitim metadata'sı |
|---|---|---|---|
| Araç | `ai-service/yolo11n.pt` | 2024-09-25 | COCO, 80 sınıf; `car` ID 2, imgsz 640; Ultralytics 8.2.100 |
| Hasar | `models/candidates/damage_detection_v2_cardd_5class.pt` | 2026-09-17 | `vehicle_damage_detection_v2/data.yaml`; epochs=100, seed=42, imgsz=640; 8.4.106 |
| Parça | `models/vehicle_part_best.pt` | 2026-07-29 | Eski yerel `datasets/vehicle_part/data.yaml` yolu; epochs=40, seed=0, imgsz=640; 8.4.106 |

Dosya yolları son iki satırda `ai-service` dizinine göredir. `epochs` eğitim argümanıdır;
tamamlanan epoch sayısı veya performans ölçümü değildir. Stripped checkpoint'teki `epoch=-1`
eğitim yapılmadığı anlamına gelmez. Metadata ve hash yereldeki varsayılan production
artifact'lerini tanımlar; Railway'de çalışan dosyalar bu çalışma sırasında indirilip karşılaştırılmadı.

```text
vehicle 0ebbc80d4a7680d14987a577cd21342b65ecfd94632bd9a8da63ae6417644ee1
damage  3f5f77fe59243695cc0a42e0bff9e283c5fc0970793d8d6d6010db959983c52b
part    5d1bed6466dfe92b3506b5bbcba50003d8ed56237d908c8709e9bb1e1f92ef71
```

## Gerçek hasar sınıfları

| Checkpoint ID / adı | Yerel CarDD kaynak sınıfı | API değeri ve kapsam |
|---|---|---|
| 0 `SCRATCH` | scratch | `SCRATCH`: çizik belirtisi |
| 1 `DENT` | dent | `DENT`: göçük belirtisi |
| 2 `CRACK` | crack | `CRACK`: çatlak belirtisi |
| 3 `BROKEN_PART` | lamp broken | Eski API kodu korunur; **yalnızca lamba kırığı belirtisi**, genel parça kırığı değil |
| 4 `BROKEN_GLASS` | glass shatter | `BROKEN_GLASS`: cam kırığı belirtisi |

Kanıt: checkpoint `model.names`, mevcut hasar `data.yaml`, `config/cardd_import.yaml`
ve yerel import raporu. `tire flat` aktarılmamıştır; sadece bu etiketi taşıyan fotoğraflar
karantinadadır. `PAINT_DAMAGE` ve `DEFORMATION` uygulama enumlarında geçmiş kayıtlar için
korunur, aktif model bunları üretmez. `NO_VISIBLE_DAMAGE` öğrenilmiş sınıf değildir.
`BROKEN_PART` yeni UNKNOWN şiddetli çıktılarda Flutter/PDF'de “Lamba Kırığı Belirtisi”
olarak gösterilir. Eski kayıtların genel kırık parça etiketi geriye dönük yeniden yorumlanmaz.

## Gerçek parça sınıfları

Yerel `datasets/vehicle_part/data.yaml` mevcuttur ve checkpoint'in 21 sınıfıyla birebir eşleşir.

| ID | Checkpoint adı | Python / Java / Flutter API değeri |
|---|---|---|
| 0 | Back-bumper | REAR_BUMPER |
| 1 | Back-door | REAR_DOOR |
| 2 | Back-wheel | REAR_WHEEL |
| 3 | Back-window | REAR_WINDOW |
| 4 | Back-windshield | REAR_WINDSHIELD |
| 5 | Fender | FENDER |
| 6 | Front-bumper | FRONT_BUMPER |
| 7 | Front-door | FRONT_DOOR |
| 8 | Front-wheel | FRONT_WHEEL |
| 9 | Front-window | FRONT_WINDOW |
| 10 | Grille | GRILLE |
| 11 | Headlight | HEADLIGHT |
| 12 | Hood | HOOD |
| 13 | License-plate | LICENSE_PLATE |
| 14 | Mirror | MIRROR |
| 15 | Quarter-panel | QUARTER_PANEL |
| 16 | Rocker-panel | ROCKER_PANEL |
| 17 | Roof | ROOF |
| 18 | Tail-light | TAIL_LIGHT |
| 19 | Trunk | TRUNK |
| 20 | Windshield | WINDSHIELD |

`UNKNOWN` güvenli uygulama sonucudur, öğrenilmiş parça sınıfı değildir. Sol/sağ,
lastik ile jant ayrımı veya mekanik iç parçalar destekleniyor sayılmaz.

## Kabul ve eşleştirme kuralları

- JPG/PNG/WEBP, dosya/piksel sınırları, parlaklık ve bulanıklık kontrolleri korunur.
  EXIF yönü inference öncesinde uygulanır; koordinatlar yönü düzeltilmiş fotoğrafa göredir.
- YOLO adayları 0.20 skorundan alınır. `truck/bus/motorcycle/bicycle/train/boat`
  işareti veya birden fazla otomobil varsa kare reddedilir. Arka plandaki araç da ret yaratabilir.
- Tek `car` adayı görüntünün en az %12'sini kaplamalıdır. Skoru en az 0.40 ise
  mevcut %5 paylı crop uygulanır.
- 0.20–0.40 arası kısmi otomobil adayı için en az iki farklı tanınan parça gerekir;
  her birinin skoru >=0.50 ve kutusunun en az yarısı otomobil adayı içinde olmalıdır.
  En az biri kaporta grubu olmalıdır: tampon, kapı, kaput, çamurluk, quarter-panel,
  rocker-panel, tavan veya bagaj. Bu durumda tam çözünürlük korunur.
  **Hiç `car` adayı yoksa parçalar tek başına otomobil varsayımı oluşturmaz.**
- `purpose=damage` aynı kuralı kullanır; `context` güçlü otomobil kanıtı ister.
  Eski çift fotoğraf endpoint'i korunur, iki fotoğraf bağımsız doğrulanır ve
  sınıf adına dayanarak fotoğraflar arasında parça taşınmaz.
- Hasar inference eşiği 0.25 olarak korunur. Yalnızca 0.25–0.30 aralığında adaylar
  varsa yeniden fotoğraf istenir; temiz sonuç veya zorunlu onarım üretilmez.
  >=0.30 bulgular raporlanır; üst düzey etkilenen parça listesi için mevcut >=0.50 hasar eşiği korunur.
- Parça eşleştirmesi için parça skoru >=0.50 ve hasar kutusu örtüşmesi >=0.50 gerekir.
  Skor `0.8*örtüşme + 0.2*parça skoru`; farklı parçalardaki ilk iki adayın farkı <0.10
  ise `UNKNOWN`. Aynı parça sınıfındaki tekrarlar tek adaydır.
- Lamba kırığı yalnızca far/stop ile; cam kırığı yalnızca pencere/ön-arka camla;
  göçük yalnızca kaporta grubuyla ilişkilendirilir. Bunlar ek model eğitimi değil,
  çelişkili eşleştirmeleri engelleyen ihtiyatlı kurallardır.
- Kullanıcı FRONT/REAR seçimiyle çelişen çiftli parça `UNKNOWN` olur; karşı parça uydurulmaz.

Bu eşikler doğruluk yüzdesi veya kalibre edilmiş olasılık değildir. Etiketli bağımsız
otomobil/desteklenmeyen araç/yakın çekim setinde kabul ve yanlış kabul oranları henüz ölçülmedi.
Modellerin yanlış `car` sınıflandırmasını bu kurallar matematiksel olarak engelleyemez.

## Sonuç, rapor ve uyumluluk

| Durum | Sonuç |
|---|---|
| Fotoğraf/otomobil kanıtı yetersiz | Ön kontrolde `suitable=false`; doğrudan analizde HTTP 400 / yeniden çekim; hasarsız rapor yok |
| Uygun fotoğrafta eşik üstü hasar adayı yok | Mevcut `NONE` + `NO_VISIBLE_DAMAGE`; yalnızca fotoğraftaki görünür hasar için |
| Desteklenen görünür hasar var, parça bulunamadı | Hasar korunur; tespit `affectedPart=UNKNOWN`, üst düzey `affectedParts=[]` |
| Desteklenen görünür hasar var | Şiddet `UNKNOWN`; onarım/değişim zorunluluğu çıkarılmaz |

Mevcut alanlar/enumlar korunur; şema migration'ı yoktur. Hasarlı yeni sonuçta `NO_ACTION`
“kanıtlanmış onarım yöntemi yok” anlamındadır; `partReplacementRequired=false` değişimin
gereksizliğini ispatlamaz. Flutter bu durumda fiziksel inceleme metni gösterir.
Java boş veya çelişkili UNKNOWN yanıtını kabul etmez; desteklenen sınıfları, tespitleri,
skorları ve belirsiz öneri alanlarını doğrular. Önceden kayıtlı MINOR/MODERATE/SEVERE
sonuçların fiyat/rapor akışı korunur.

**Ürün davranışı değişikliği:** yeni hasarlı analizlerde model şiddet/onarım öğrenmediği
için otomatik kesin yöntem, değişim veya fiyat aralığı üretilmez. Rapor yerel ve
deterministik oluşturulur; Gemini fiyat çağrısı yapılmaz. Mevcut nullable fiyat alanları
`null` kalır. Flutter bunu 0 TL'ye dönüştürmez. Model skoru 0–1 olarak, doğruluk yüzdesi
olmadığı açıklamasıyla gösterilir. Rapor yenileme aynı belirsizlik kuralını izler.

Kredi ayırma/tamamlama/serbest bırakma ve abonelik kuralları değiştirilmedi.
Başarıyla tamamlanan görünür hasar raporu mevcut kredi kuralına tabidir; değerlendirme
başarısızsa ücretli rezervasyon bırakılır. Replay yeniden inference/ücret oluşturmaz.

Gelecekte yayınlanırken uyumlu Flutter ve Java sürümleri AI değişikliğinden önce hazır
olmalıdır. Eski kurulu mobil sürümün nullable fiyatı 0, hasarlı `NO_ACTION` değerini
“İşlem Gerekmiyor” göstermesi bilinen uyumsuz sunumdur; uyumlu minimum mobil sürüm
zorunluluğu çözülmeden yeni AI davranışı production'a açılmamalıdır. Bu çalışma
production ayarı veya mobil sürüm zorunluluğu değiştirmedi. Yeni anahtar/dataset indirmesi gerekmez.

## Veri ve değerlendirme sınırları

- Hasar label dosyaları: train 2644, val 768, test 349. Import raporu 4000 kaynaktan
  3761 aktarım / 239 karantina ve 8421 kutu bildirir. Split'ler eğitim metadata'sı
  ile ilişkilidir; yeni veri entegrasyonu yapılmadı.
- Parça label dosyaları: train 699, valid 199, test 100. Kaynak veri setinin sürümü,
  lisansı, özgün yayın adresi, araç türü kapsamı, anotasyon politikası ve split üretim
  geçmişi mevcut YAML/checkpoint'ten doğrulanamıyor. Bunlar varsayılmadı.
- Checkpoint içinde dataset içerik hash'i yok; mevcut yerel verinin eğitim anındaki
  veriyle birebir aynı olduğu, veri sızıntısı olmadığı ve sınıfların yeterli öğrenildiği
  kanıtlanmış değildir. Sınıf başlığı bulunması yüksek performans garantisi değildir.
- Yerel dört etiketsiz smoke fotoğrafının ikisi tamamlandı, ikisi yeniden çekim istedi.
  `carsc.jpg` hasarı artık tekerleğe zorla bağlanmadı; parça UNKNOWN kaldı.
  `scratch.jpg` tampon bulgusuyla tamamlandı. Çok araçlı kare reddedildi.
  `scratch1.jpg` görsel olarak otomobil yakın çekimine benziyor ancak genel model
  `train=0.2354` ürettiği için reddedildi: **bilinen yanlış ret / yakın çekim sınırlaması**.
  Bunlar accuracy/precision/recall ölçümü değildir; test fotoğraflarıyla eğitim yapılmadı.

## Doğrulama ve dosyalar

- Python tam paket: 138 test geçti.
- Java son tam paket: 297 çalıştı, 295 geçti, 2 Docker gerektiren test atlandı
  (`AiAssistantBusinessConcurrencyIT`, `AiAssistantServiceConcurrencyIT`).
  PostgreSQL kredi testleri, yeni UNKNOWN şiddet/null fiyat kalıcılık ve rapor
  yenileme testi, kredi replay/başarısızlık testleri pakete dahildir.
- Flutter tam paket: 222 geçti; son metin/format değişikliklerinden sonra sonuç ve
  farklı ekran boyutları paketi 31 geçti; `flutter analyze --no-pub` temiz.
- Ortak wire örneği: `contracts/car-analysis-v1.json`; Python şeması/üreticisi,
  korumalı ASGI endpoint'i, Java servis akışı ve Flutter model/ekranı bunu kullanır.
- Gerçek checkpoint yükleme, sınıf/YAML doğrulaması ve dört yerel fotoğraf smoke kontrolü yapıldı.
  Ağırlık hash'leri korunur. Eğitim veya deployment testi yapılmadı.

Ana değişen dosyalar: `ai-service/app/damage_analyzer.py`, `app/model_contract.py`,
`scripts/audit_production_models.py`, ilgili Python testleri; Java
`DamageInspectionService`, `AiAnalysisClient`, `VehicleOverviewService` ve servis testleri;
Flutter `inspection_report.dart`, sonuç/yükleme/araç detay ekranları, iki PDF servisi
ve sonuç ekranı testleri. Tam dosya listesi branch diff'inde bulunur.

Yerel test logları `target/car-*` altında tutulur; Git'e model ağırlığı veya veri görüntüsü eklenmez.
