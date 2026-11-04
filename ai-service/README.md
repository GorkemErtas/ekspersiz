# EksperSiz AI servisi

FastAPI iki bağımsız sorumluluk taşır: Gemini ile iki fotoğraflı görsel hasar yorumu ve
AI Asistan için semantic routing, yerel E5 embedding, pgvector RAG. Java yetki, ödeme,
kredi, kalıcı kayıt ve rapor süreçlerinin otoritesidir.

## Yerel kullanım

```powershell
python -m venv venv
venv/Scripts/python.exe -m pip install -r requirements.txt
# .env.example değerlerini ortam değişkenleri olarak tanımlayın.
venv/Scripts/python.exe -m uvicorn main:app --host 127.0.0.1 --port 8000
```

`/health` dışındaki uçlar en az 32 karakterlik `X-AI-Service-Key` ister.
`POST /api/v1/analyze`, `image` (yakın detay) ve `context_image` (genel görünüm)
multipart alanlarını birlikte gerektirir. İkisi tek Gemini çağrısında işlenir.
`POST /api/v1/validate-image` yalnız yerel dosya kontrolüdür; Gemini çağrısı yapmaz.
`GET /api/v1/vision/readiness` anahtar/yapılandırma hazır oluşunu bildirir; ücretli bir test çağrısı yapmaz.

Native JSON Schema, Pydantic doğrulaması, süre/token sınırı ve yalnız açık HTTP 429 reddinde
bir yeniden deneme bulunur. Fotoğraflar burada saklanmaz; EXIF/GPS temizlenmiş ve en fazla
2048 piksele ölçeklenmiş iki JPEG inline gönderilir. Cloud Files/caching kullanılmaz.
API anahtarları ve fotoğraflar loglanmaz. Günlüklerde model, süre, tokenlar ve yapılandırılmış
birim fiyatlardan hesaplanan yaklaşık API maliyeti yer alır.

## Asistan

`POST /api/v1/assistant/plan`, kapsam/kaynak yönlendirmesini sürdürür. E5 ve
SentenceTransformers için **PyTorch korunur**. `knowledge/`, `scripts/ingest_assistant_knowledge.py`,
embedding, pgvector ve semantic routing görsel analizden bağımsızdır.
Docker, CPU PyTorch ve mevcut E5 modelini içerir. Kaynak belgeler değiştiğinde bilgi tabanı
yalnız yetkili, açık ingestion komutuyla güncellenir; bu çalışma çalışan veritabanını değiştirmez.

## Test

```powershell
venv/Scripts/python.exe -m unittest discover -s tests -v
```

48 MP reddetme fixture'ı `tests/fixtures/` içindedir; testler `mobile/` klasörüne bağlı değildir. Native hazırlayıcıdan gelen `detail.jpg` ve `overview.jpg` için isteğe bağlı `MOBILE_IMAGE_CONTRACT_DIR` ayarlanabilir.

Görsel analiz testleri Gemini'yi mock eder; dış sağlayıcıya fotoğraf veya ücretli istek göndermez.
[Tam sözleşme, yapılandırma ve sınırlar](../docs/GEMINI_VISION_ANALYSIS.md).
