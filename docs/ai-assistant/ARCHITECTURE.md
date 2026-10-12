# EksperSiz AI Asistan — Güncel Mimari

> Bu belge mevcut uygulama kodunu açıklar. Eski 30 günlük bağımsız AI Asistan denemesi ve ayrı asistan aboneliği tasarımı geçerli değildir.

## Amaç ve sınırlar

- Türkçe ağırlıklı, otomotiv ve EksperSiz odaklı asistan; Flutter'da yazılı sohbet ve cihaz üzerinde konuşmayı metne çevirme desteği.
- Kişisel araç, hatırlatma ve hasar verileri **vektör bilgi tabanına gömülmez**. Kullanıcı kimliği JWT üzerinden Spring Boot tarafından doğrulanır.
- Genel otomotiv bilgisi, uygulama dokümanları ve kişisel kullanıcı verileri **farklı kaynak yollarıyla** ele alınır.

## Gerçek istek akışı

1. Flutter `AiAssistantScreen` soruyu, en fazla sınırlı sohbet geçmişini ve isteğe bağlı seçili araç kimliğini Spring Boot'a gönderir.
2. `AiAssistantChatService` erişimi ve kotayı kontrol eder; seçili araç bilgisini kullanıcı yetkisiyle doğrular.
3. FastAPI `/api/v1/assistant/plan`, `SemanticDomainClassifier` üzerinden **Gemini `gemini-3.5-flash-lite`** ile anlamsal kapsam, niyet ve bilgi kaynağı seçimi yapar. Bu aşama da bir LLM API çağrısıdır; sıfır maliyetli değildir.
4. Kapsam dışı sorular için sabit ret mesajı verilir; **ana yanıt üretimi çalıştırılmaz**. Tekrarlanan kapsam dışı istekler 24 saatlik geçici kilide yol açabilir.
5. Eksik kritik bilgi varsa kısa açıklama istenir; yanıt hakkı tüketilmez.
6. Kaynak rotası:
   - `APP_KNOWLEDGE`: EksperSiz'e özel küratörlü dokümanlarda **RAG/pgvector**; yeterli kanıt yoksa cevap uydurulmaz.
   - `PUBLIC_WEB`: Kamuya açık otomotiv bilgisi; Spring Boot'ta Gemini **Google Search grounding** aracı kullanılabilir. Özellikle kesin teknik özelliklerde kaynak doğrulaması istenir.
   - `USER_DATA`: Yalnızca yetkili Spring Boot araçlarıyla kullanıcının kayıtlı verileri; web/RAG üzerinden özel veri aranmaz.
7. Backend, planın kaynak/araç kombinasyonunu doğrular. Kullanıcı verisi için izin verilen araçlar: `getMyVehicles`, `getUpcomingReminders`, `getDamageHistory`.
8. Yanıt öncesi sunucuda günlük kota **rezervasyonu** yapılır; Gemini yanıtı başarılıysa kullanım işlenir, hata olursa rezervasyon serbest bırakılır.
9. Flutter yanıtı, varsa kaynakları ve güncel kalan kullanım hakkını gösterir.

## RAG bileşenleri

- Bilgi kaynağı: `ai-service/knowledge` ve `sources.json`; mevcut manifest yalnızca `APP_HELP` kategorisinin özel bilgi tabanına alınmasına izin verir.
- Ingestion: `scripts/ingest_assistant_knowledge.py` → manifest doğrulama → PDF/Markdown ayrıştırma → anlamsal parçalama → embedding → sürümlü PostgreSQL/pgvector.
- Embedding: `intfloat/multilingual-e5-small`, **384 boyut**, yerel çalışır; üretim Docker imajına önceden indirilir.
- Retrieval: varsayılan 8 aday, 4 son parça; benzerlik ve kanıt eşikleri `app/assistant/settings.py` içinden yapılandırılır.
- Kaynak metadata/sürüm yönetimi; aktif belge seçimi ve içerik değişmediyse gereksiz yeniden embedding'den kaçınma.
- Araç/hasar geçmişi gibi özel veriler RAG'e yazılmaz.

## Niyetler

`VEHICLE_GENERAL`, `INSPECTION`, `MAINTENANCE`, `DRIVING_USAGE`, `SAFETY`, `VEHICLE_SPEC`, `USER_VEHICLE`, `DAMAGE_HISTORY`, `REMINDER`, `APP_HELP`, `OUT_OF_SCOPE`.

## Plan, deneme ve kota

| Plan | AI Asistan başarılı yanıt hakkı |
| --- | --- |
| FREE | Erişim yok |
| PLUS | Günde 3 |
| PRO | Günde 5 |
| BUSINESS | Şirket genelinde günde 10 |

- FREE kullanıcı, **profilden bir kez 7 günlük PLUS denemesi** başlatabilir; ödeme yöntemi veya otomatik ücretli dönüşüm yoktur.
- Aktif ücretli plan veya henüz dolmamış abonelik dönemi sunucuda etkin plan olarak değerlendirilir.
- Başarılı yanıtlar kota tüketir; kapsam dışı, açıklama isteyen ve başarısız istekler tüketmez.
- Eşzamanlı istekler için süreli kota rezervasyonu; üç kapsam dışı denemeden sonra 24 saatlik kilit mantığı bulunur.
- Asistan kotası ile aylık hasar analizi kotası ayrı sayaçlardır.

## Güvenlik, maliyet ve doğruluk

- LLM tarafından önerilen yönlendirme, backend'de izinli kaynak/araç listesiyle sınırlandırılır; kullanıcı ID'si LLM'den alınmaz.
- Kullanıcı mesajı, geçmiş ve kaynaklar güvenilmeyen içerik sayılır; prompt-injection yönergeleri talimat kabul edilmez.
- Konu dışı sorularda ana Gemini yanıt çağrısı atlanır; **sınıflandırma çağrısı ücretli olabilir**. Tasarruf oranı ölçülmeden iddia edilmemelidir.
- En fazla sınırlı sohbet geçmişi taşınır; yeterli RAG kanıtı bulunmazsa cevap yerine belirsizlik bildirilir.
- Ölçülmesi gerekenler: sınıflandırma doğruluğu, yanlış ret, RAG Recall@k, kaynak doğruluğu, araç yetkilendirme hataları, sınıflandırma/yanıt token ve maliyetleri.

## Kod referansları

- `ai-service/app/assistant/domain_classifier.py`, `routing.py`, `retriever.py`, `source_manifest.py`
- `ai-service/main.py`, `scripts/ingest_assistant_knowledge.py`
- `src/main/java/com/gorkem/vehicle_inspector/service/AiAssistantChatService.java`
- `AiAssistantEntitlementService.java`, `AiAssistantGenerationService.java`, `AiAssistantToolContextService.java`
- `mobile/lib/features/ai_assistant/`
