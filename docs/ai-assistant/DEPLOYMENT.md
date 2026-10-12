# EksperSiz AI Asistan — Dağıtım ve Bilgi Tabanı Yönetimi

## Mevcut yapı

- **Spring Boot API:** JWT, plan/kota, kullanıcı araçları, Gemini yanıt üretimi.
- **FastAPI AI servisi:** YOLO hasar analizi ve AI Asistan kapsam yönlendirme/RAG; aynı Docker dağıtım birimi, farklı sağlık kontrolleri.
- **PostgreSQL + pgvector:** Uygulama verileri ve sürümlü, yalnızca küratörlü EksperSiz bilgi tabanı.
- **Railway / Docker:** Backend ve AI servisi ayrı konteynerler; gizli anahtarlar ortam değişkenlerinde.

## Üretime alma kontrol listesi

1. PostgreSQL yedeği al; `vector` eklentisini ve bağlantı yetkilerini doğrula.
2. Backend'i dağıt; **Flyway V1–V12** şema geçişlerinin uygulandığını kontrol et.
3. AI servis imajını dağıt. İmaj `intfloat/multilingual-e5-small` embedding modelini önceden içerir; üretimde `ASSISTANT_EMBEDDING_LOCAL_ONLY=true` olmalıdır.
4. YOLO ağırlıklarının Docker imajında mevcut olduğunu kontrol et: `yolo11n.pt`, `models/vehicle_part_best.pt`, `models/candidates/damage_detection_v2_cardd_5class.pt`.
5. Bilgi tabanını **uygulama başlangıcında değil**, ayrı yönetim/dağıtım adımı olarak işle:
   ```bash
   cd ai-service
   python scripts/ingest_assistant_knowledge.py --source-version <surum>
   ```
6. `GET /health` ile AI servisinin temel sağlığını doğrula.
7. `GET /api/v1/assistant/readiness` ile pgvector, aktif belge/parça ve **384 boyutlu embedding** hazırlığını doğrula.
8. Kapsam dışı, uygulama bilgisi (RAG), kamuya açık otomotiv bilgisi (Google Search), yetkili araç verisi ve günlük kota akışlarını smoke-test et.
9. Flutter AI Asistan ekranını yalnızca ilgili servisler hazırken kullanıcıya sun.

## Bilgi kaynağı ekleme ve güncelleme

- Dosyaları `ai-service/knowledge` altına yerleştir; `knowledge/sources.json` manifestini güncelle.
- Güncel `source_manifest.py` yalnızca **`APP_HELP`** bilgi kaynağını ingest etmeye izin verir. Genel otomotiv bilgisini bu özel vektör tabanına eklemeyin.
- Markdown ve desteklenen PDF belgeleri parser üzerinden işlenebilir; kaynak kimliği, sürüm, yetki düzeyi ve metadata doğrulanır.
- İçerik hash'i değişmeyen belgeler yeniden işlenmez; güncellenen kaynaklar sürümlenir, önceki aktif sürüm `SUPERSEDED` olur.
- Manifestte etkin kaynak bulunmuyorsa veya kaynak boşsa işlem, bilgi tabanını topluca emekliye ayırmamak için hata verir.
- Kullanıcıların özel araç, analiz veya hesap verilerini bilgi tabanına ingest etmeyin.
- Ingestion sonrası readiness ve örnek sorularla yanıt kalitesini tekrar doğrulayın.

## Önemli ortam değişkenleri

| Değişken | Amaç |
| --- | --- |
| `DATABASE_URL` | AI servisi pgvector/PostgreSQL bağlantısı |
| `AI_SERVICE_BASE_URL` | Spring Boot → FastAPI adresi |
| `GEMINI_API_KEY` | Yönlendirme ve yanıt üretimi |
| `ASSISTANT_ROUTER_MODEL` | Kapsam modeli; varsayılan `gemini-3.5-flash-lite` |
| `ASSISTANT_ROUTER_TIMEOUT_SECONDS` | Kapsam modeli zaman aşımı; varsayılan 8 sn |
| `ASSISTANT_EMBEDDING_MODEL` | Varsayılan `intfloat/multilingual-e5-small` |
| `ASSISTANT_EMBEDDING_LOCAL_ONLY` | Üretimde yerel embedding modeli |
| `KNOWLEDGE_SOURCE_VERSION` | Bilgi kaynağı sürümü |
| `ASSISTANT_CHUNK_TARGET_TOKENS` | Parça hedefi; 420 |
| `ASSISTANT_CHUNK_MIN_TOKENS` / `ASSISTANT_CHUNK_MAX_TOKENS` | 120 / 560 |
| `ASSISTANT_CHUNK_SIMILARITY_THRESHOLD` | 0.72 |
| `ASSISTANT_RETRIEVAL_CANDIDATE_K` / `ASSISTANT_RETRIEVAL_FINAL_K` | 8 / 4 |
| `ASSISTANT_RETRIEVAL_MIN_SIMILARITY` | 0.55 |
| `ASSISTANT_EVIDENCE_MIN_SIMILARITY` | 0.62 |
| `ASSISTANT_VEHICLE_SPEC_MIN_SIMILARITY` | 0.78 |
| `AI_ASSISTANT_USAGE_ZONE` | Günlük kota zaman dilimi; `Europe/Istanbul` |
| `AI_ASSISTANT_RESERVATION_TTL` | Kota rezervasyonu; varsayılan `PT5M` |

Backend'in PostgreSQL kimlik bilgileri, JWT sırrı ve diğer entegrasyon anahtarları da ortamdan sağlanmalıdır; gerçek sırları GitHub'a yazmayın.

## Test ve geri alma

- AI birim testleri: `cd ai-service && pytest`.
- Backend: `./mvnw test`; mobil: `cd mobile && flutter test`.
- Örnek değerlendirme senaryoları: [evaluation-v1.jsonl](evaluation-v1.jsonl); bu dosya **test verisidir**, tek başına otomatik test çalıştırmaz.
- Sorunlu uygulama sürümünü önceki Docker imajına geri al; bilgi tabanı sürümlerini ayrıca ele al. Eski belgeler `SUPERSEDED` olarak saklanır; otomatik tek komutluk geri alma varsayılmamalıdır.
- Hasar analizi `/health` kontrolünü RAG readiness'e bağlama; bir bileşendeki sorun diğerinin sağlık sonucunu gizlememeli.
- Trafik artarsa AI Asistan ve hasar analizi ayrı servisler hâline getirilebilir; bu **gelecekteki ölçeklendirme seçeneğidir**, mevcut kurulum değildir.
