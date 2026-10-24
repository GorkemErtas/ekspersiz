# EksperSiz AI servisi

FastAPI servisi AI Asistan kapsam/kaynak yönlendirmesini, E5 metin embedding'lerini ve pgvector RAG erişimini sağlar. Aktif görüntü/hasar tespit modeli, eğitim veri seti veya eğitim/değerlendirme aracı bulunmaz.

## API davranışı

- `GET /health`: servis durumu `UP`, `damageAnalysis` durumu `UNAVAILABLE`.
- `POST /api/v1/analyze` ve `POST /api/v1/validate-image`: kimliği doğrulanmış isteklere `503`, `DAMAGE_ANALYSIS_UNAVAILABLE`. Görüntü okunmaz, sahte analiz veya hasarsız sonuç üretilmez.
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

`requirements.txt`, ortak runtime listesini kullanır. PyTorch, NumPy ve Pillow, SentenceTransformers tabanlı AI Asistan için korunur. Docker CPU PyTorch kurar ve mevcut E5 embedding modelini imaja alır; görüntü modeli indirme/yükleme adımı yoktur.

Asistan ortam ayarları ve bilgi tabanı yükleme adımları: [dağıtım](../docs/ai-assistant/DEPLOYMENT.md), [bilgi tabanı](knowledge/README.md).

## Gelecekteki hasar sağlayıcısı

Yeni sağlayıcı entegre edilene kadar kullanılabilirlik kapalı kalır. Java `AiAnalysisClient`, modelden bağımsız sınırdır. Yeni sağlayıcı; açık kullanılabilirlik kontrolü, dosya güvenliği, mevcut geçmiş/rapor DTO'ları ve başarısız işlemde kredi tüketmeme sözleşmesiyle entegre edilmelidir. Eski sınıf indeksleri veya eğitim eşlemeleri kullanılmaz. Bu değişiklik yeni model eklemez.
