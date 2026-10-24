# EksperSiz AI servisi

FastAPI servisi AI Asistan kapsam/kaynak yönlendirmesini, E5 metin embedding'lerini ve pgvector RAG erişimini sağlar. HITL'nin 8 hasar ve 21 parça sınıfı için tek YOLOX-Tiny / iki head eğitim ve ONNX inference altyapısı eklenmiştir. Model, düşük hasar doğruluğu nedeniyle üretim için onaylanmamıştır; görüntü özelliği varsayılan kapalıdır.

## API davranışı

- `GET /health`: genel servis durumu `UP`. `/api/v1/vision/readiness`, açık release ayarı ve doğrulanmış bundle olmadan 503 döner.
- `POST /api/v1/analyze` ve `POST /api/v1/validate-image`: varsayılan kapalı durumda kimliği doğrulanmış isteklere `503`, `DAMAGE_ANALYSIS_UNAVAILABLE`. Görüntü okunmaz, sahte analiz veya hasarsız sonuç üretilmez.
- `/api/v1/assistant/plan` ve `/api/v1/assistant/readiness`: mevcut asistan sözleşmeleri korunur.

Backend, analiz/doğrulamayı kredi rezervasyonu ve durum değişikliğinden önce durdurur. Geçmiş analiz verileri, görseller, hasar/parça enum'ları, rapor üretimi ve PDF akışı korunur. Rapor yeniden üretimi kaydedilmiş başarılı analizden devam eder.

## Kurulum ve test

```bash
python -m venv venv
# Sanal ortamı etkinleştirdikten sonra:
python -m pip install -r requirements.txt
python -m unittest discover -s tests -v
uvicorn main:app --host 0.0.0.0 --port 8000
```

`requirements.txt`, runtime listesini kullanır. PyTorch, SentenceTransformers tabanlı AI Asistan için korunur; görüntü çıkarımı ONNX Runtime kullanır. Docker CPU PyTorch ve mevcut E5 embedding modelini içerir; `ml/`, eğitim/export araçları ve ham veriler imaja alınmaz. Vision bundle dışarıdan bağlanır, çalışma anında indirilmez. Geliştirme/ML testleri için `requirements-training.txt` kullanılır.

Asistan ortam ayarları ve bilgi tabanı yükleme adımları: [dağıtım](../docs/ai-assistant/DEPLOYMENT.md), [bilgi tabanı](knowledge/README.md).

## Birleşik model ve eğitim

Supervisely→COCO dönüşümü, görev maskeli eğitim, değerlendirme, ONNX export/parity ve CPU benchmark komutları [birleşik model belgesindedir](../docs/ml/UNIFIED_YOLOX_TINY.md). [Sınıf sayıları](../docs/ml/HITL_CLASS_COUNTS.md) ve [gerçek sonuçlar](../docs/ml/HITL_RESULTS.json) ayrıca kaydedilir. Export `production_approved: false` üretir. Java, Python ve Flutter release kapıları açıkça değiştirilmeden üretim aktive edilmez. Eski ağırlıklar ve Ultralytics kullanılmaz.
