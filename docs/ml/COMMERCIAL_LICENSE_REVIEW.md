# Ticari kullanım ve kaynak incelemesi — 24–25 Ekim 2026

Kod, eğitim verisi ve hazır ağırlık ayrı bileşenler olarak incelenir. Aşağıdaki
kararlar yayıncı belgelerine dayanır; bir depo veya ayna üzerindeki etiket tek
başına üçüncü taraf fotoğrafların haklarını kanıtlamaz. Deneylerde Ultralytics
paketi, kodu veya ağırlığı kullanılmaz. Hiçbir ücretli hizmete veri yüklenmez.

| Bileşen | Asıl yayıncı / kanıt | Karar |
| --- | --- | --- |
| HITL car parts / damages | [HITL yayını](https://humansintheloop.org/resources/datasets/car-parts-and-car-damages-dataset/): 998 parça, 814 hasar görüntüsü; Beetroot Academy anotasyonu; veri seti CC0 1.0 | Mevcut veri kullanılır; yerel meta/sınıf/sayıları yayıncı tanımıyla eşleşir. Ham içerik değiştirilmez. Yayıncı tek tek fotoğrafın çekim/temin zincirini yayımlamaz; bu sınır gizlenmez. |
| RF-DETR Python framework | [Asıl kaynak](https://github.com/roboflow/rf-detr), kurulan `rfdetr==1.11.2` dağıtımının LICENSE dosyası | Apache-2.0; offline eğitim ortamıyla sınırlı. |
| RF-DETR Nano detection COCO ağırlığı | [Yayıncının ayrı model lisansı açıklaması](https://roboflow.com/blog/rf-detr-is-free-to-use-commercially), [model sayfası](https://playground.roboflow.com/models/roboflow/rf-detr), kurulan paketin `RFDETRNanoConfig.license` ve resmî asset kaydı | Apache-2.0 açıkça modelleri ve kodu kapsar; `rf-detr-nano.pth` allowlist ile kullanılır. |
| RF-DETR Seg Nano COCO ağırlığı | [Asıl proje](https://github.com/roboflow/rf-detr), `RFDETRSegNanoConfig.license=Apache-2.0`, resmî asset kaydı | Apache-2.0 olarak tanımlanan Nano segmentation ağırlığı; Plus modelleri indirilmez. |
| DINOv2 omurgası | [Meta resmî kaynak ve model lisansı](https://github.com/facebookresearch/dinov2) | Apache-2.0 kod/model; ayrıca bilinmeyen bir omurga ağırlığı indirilmez. RF-DETR yayıncı checkpoint'i kullanılır. |
| RT-DETR native uygulaması | [Hugging Face resmî belgeleri](https://huggingface.co/docs/transformers/model_doc/rt_detr), kurulu `transformers==5.20.2` LICENSE dosyası | Apache-2.0; yalnızca offline eğitim/export. Runtime Transformers import etmez. |
| YOLOX yerel baseline | [Sabit kaynak revizyonu](https://github.com/Megvii-BaseDetection/YOLOX/tree/6ddff4824372906469a7fae2dc3206c7aa4bbaee), vendor LICENSE/NOTICE | Apache-2.0 kod; yalnızca önceki HITL üzerinde sıfırdan eğitilmiş yerel checkpoint. Haricî YOLOX pretrained ağırlığı kullanılmaz. |
| ONNX / ONNX Runtime | [ONNX](https://github.com/onnx/onnx), [ORT](https://github.com/microsoft/onnxruntime) | Apache-2.0 / MIT; çalışma zamanı Torch veya RF-DETR import etmez. |

RF-DETR ağırlıkları asıl paketin işaret ettiği `storage.googleapis.com/rfdetr/`
adreslerinden indirilir. Dosya adı ve yayıncının MD5 değeri allowlist ile
doğrulanır; indirilen içeriğin SHA-256 değeri her gerçek deneyin
`experiment.json` kaydında ayrıca tutulur. Model bundle'ında Apache lisansı,
kaynak ağırlık kimliği ve değişiklik bildirimi korunmalıdır. Ağırlık lisansı,
COCO eğitim görüntülerinin yeniden dağıtım izni olarak kullanılmaz; COCO
görüntüleri bu görevde indirilmez veya yeniden dağıtılmaz.

## Yeni veri adayları ve reddetme nedenleri

| Aday | Asıl kaynak | Deney kararı |
| --- | --- | --- |
| CarDD | [Yayıncı sayfası ve lisans formu](https://cardd-ustc.github.io/) | Açık ticari izin doğrulanmadı; kullanılmaz, aynadan indirilmez. |
| CDDM | [SCUT-CCNL resmî repo ve lisans formu](https://github.com/SCUT-CCNL/CDDM) | Erişim/lisans formu ayrı; açık ticari izin doğrulanmadı, kullanılmaz. |
| DSMLR car parts | [IT-KMITL asıl repo](https://github.com/dsmlr/Car-Parts-Segmentation) | Makale atfı tek başına ticari veri lisansı değildir; kullanılmaz. |
| Copart scrape / salvage görüntüleri | [Yayınlanan örnek ve şartlar](https://github.com/rebrowser/copart-dataset) | Ücretsiz örnek araştırma/ticari olmayan kullanım için; ticari izin ayrıca ücretli, kullanılmaz. |
| VehiDE | [Asıl makale](https://www.tandfonline.com/doi/full/10.1080/24751839.2024.2367387) | Flickr/Shutterstock kaynakları ve ticari olmayan araştırma sınırı; kullanılmaz. |
| PIXTA 10.000 hasarlı araç görüntüsü | [Asıl ticari veri ürünü](https://www.pixta.ai/datasets/pixta-ai-damaged-recognition-damaged-car-images-10-000-images-d4dba6c6-1e97-4ce8-927b-95980bff0476) | Kaynak ticari veri sağlayıcısıdır; ürün sayfası tek başına kullanım lisansı değildir. Sözleşme/izin edinilmedi, veri satın alınmadı veya kullanılmadı. |
| SYNDCAR v1 | [DTx CoLAB / Minho Üniversitesi yayını](https://data.mendeley.com/datasets/hzpj48krdt/1), DOI 10.17632/hzpj48krdt.1 | CC BY 4.0 doğrulandı. Beş cihazla çekilen 245 sentetik hasar fotoğrafı; yayıncı API'si ve SHA-256 ile kaynak doğrulaması. Önce bağımsız kaynak/alan farkı incelemesi; HITL eğitimine sessizce karıştırılmaz. |
| Roboflow Universe / Kaggle yeniden yüklemeleri | Proje bazında değişen lisanslar | Kaynak fotoğrafların hak zinciri ve asıl yayıncının izni doğrulanmadan eklenmez; HITL kopyaları yeni bağımsız veri sayılmaz. |
| Torchvision pretrained detector alternatifleri | [Resmî model belgeleri](https://docs.pytorch.org/vision/stable/models.html) | Kod lisansı ağırlık haklarını tek başına kanıtlamaz; bu görevde bu ağırlıklar indirilmez. |
| RT-DETR R18 COCO pretrained ağırlığı | [Asıl proje](https://github.com/lyuwenyu/RT-DETR), [yayıncı ağırlık kartı](https://huggingface.co/PekingU/rtdetr_r18vd) | Kod ve model ağırlığı ayrı ayrı Apache-2.0 olarak tanımlıdır. Resmî depo revizyonu `ac77a11ff0170a41b771c03264987f8ce2b0d753`, safetensors SHA-256 `fe87a5a30f5daf298d10794c7682a63b6107986f97d6a770ba948d89e4340093` ile indirildi. Dataset, framework ve model lisansları birbirine izin sayılmaz. Eğitim/karşılaştırma durumu gerçek deney kayıtlarında tutulur. |

SYNDCAR'ın tüm sınıfları HITL ile eşanlamlı değildir; `broken glass` veya
`broken lights` etiketleri otomatik olarak `Cracked` ya da `Broken part` yapılmaz.
CC BY 4.0 atfı, DOI, yazarlar ve değişiklik bilgisi yerel veri yanında korunur.
Kaynaktan gelen annotation biçimini okumak, Ultralytics paketini kullanmak anlamına gelmez;
veri arşivindeki eğitim/hazırlama kodu çalıştırılmaz.

Mevcut eğitim seti bilinmeyen kaynaklı görüntülerle büyütülmez. Hasarsız araçlar, araç olmayan görüntüler ve
nadir hasarlar için izinli saha verisi ve uzman anotasyonu gerekir. Bu eksiklik
production onayını engeller; sentetik tekrarlar yeni bilgi veya bağımsız test
verisi olarak sayılmaz.
