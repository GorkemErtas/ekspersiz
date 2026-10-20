# Kısa ve biçimlendirilmiş AI Asistan yanıtları

20 Ekim 2026 · Dal: `fix/assistant-concise-markdown`

## İnceleme ve kapsam

Python `/assistant/plan` endpoint'i routing, RAG ve kanıt yeterliliğini belirliyor.
Java `AiAssistantChatService` yetkili araç bağlamını ve kredi rezervasyonunu
yönetiyor; `AiAssistantGenerationService` Gemini yanıtını üretiyor. Flutter
önceden yanıtı düz `Text` ile çiziyordu. Üretim çağrısında açık token bütçesi ve
tamamlanma kontrolü yoktu; sistem kuralları kullanıcı metniyle aynı alandaydı.

Routing, retrieval, kanıt eşikleri, model seçimi, tool yetkilendirmesi, kaynak
DTO'ları, API sözleşmesi ve kredi iş mantığı korundu. Python üretim kodu değişmedi.

## Yanıt üretimi

- Kurallar gerçek `systemInstruction` alanında. Varsayılan 2–4 cümle veya kısa
  maddeler; açık detay isteğinde kapsamlı yanıt. Gereksiz giriş, soru tekrarı ve
  sonuç özeti istenmiyor. Başlık yalnız uzun yanıtta gerektiğinde kullanılıyor.
- Kritik güvenlik uyarıları, belirsizlik ve gerekli kaynak atıfları uzunluk
  tercihinden öncelikli. Geçmiş kanıt sayılmıyor; veri alanlarındaki rol/kural
  değiştirme talimatlarının uygulanmaması açıkça belirtiliyor.
- `PUBLIC_WEB` için gerektiğinde Google Search; `APP_KNOWLEDGE` için yalnız RAG;
  `USER_DATA` için yalnız yetkili tool verisi. Web aracı özel kaynaklarda açılmıyor.
- Promptta boş bağlam bölümleri ve diğer route'a ait veriler gönderilmiyor.
  Birebir aynı RAG chunk'ı bir kez gönderiliyor; kanıt metni kesilmiyor ve kaynak
  listesi korunuyor. Son altı konuşma mesajı kullanılmaya devam ediyor.
- `maxOutputTokens` varsayılan **4096**. `MAX_TOKENS` durumunda aynı soru ve
  kanıtlarla, **8192** bütçeyle yalnız bir kez baştan üretim yapılır. Kısmi yanıtlar
  birleştirilmez; ikinci deneme de eksikse tamamlanmış yanıt gibi sunulmaz.
  Mevcut hata/rezervasyon akışı krediyi serbest bırakır. Diğer hatalarda yeni bir
  ücretli üretim denenmez.

Bu limitler hedef yanıt uzunluğu değildir. Düşünme tokenları da bu tavana dahil
olabildiği için 2–4 cümlelik sert bir token tavanı kullanılmadı. Bkz.
[Google token limiti açıklaması](https://ai.google.dev/gemini-api/docs/generate-content/thinking?hl=en).
Normal yanıtların kısa olması promptla yönlendirilir; ölçülmüş maliyet düşüşü
iddia edilmez. Canlı model/ücretli API değerlendirmesi çalıştırılmadı.

Ortam değişkenleri: `AI_ASSISTANT_MAX_OUTPUT_TOKENS=4096` ve
`AI_ASSISTANT_RETRY_MAX_OUTPUT_TOKENS=8192`. Başlangıçta bütçeler doğrulanır:
ilk limit en az 1024, retry daha büyük ve en çok 16384 olmalıdır. Modelin düşünme
ayarları veya güvenlik filtreleri değiştirilmedi.

## Flutter

Asistan yanıtları [flutter_markdown_plus 1.0.12](https://pub.dev/packages/flutter_markdown_plus)
ile mevcut sohbet kaydırma alanı içinde çizilir. Başlıklar, paragraflar, kalın
vurgular, sıralı/sırasız listeler ve web kaynak bağlantıları desteklenir.
Tema renkleri ve sistem yazı ölçeği korunur; metin seçilebilir. Kullanıcının
kendi mesajı düz metin olarak kalır. Kaynak rozetleri korunur.

Yalnız `http/https` kaynakları kullanıcı dokunuşuyla açılır; başarısız açılışta
geri bildirim gösterilir. Markdown görselleri ağdan yüklenmez, alternatif
metinleri gösterilir. Yalnız renderer ve onun Markdown parser bağımlılığı eklendi.

API geçmiş mesajlarında mevcut 2000 karakter sınırı sürüyor. Ayrıntılı eski
yanıtlar bu sınırı aşarsa **yalnız gönderilen geçmiş** başı ve sonu korunarak
daraltılır; çıkarılan orta bölüm açıkça işaretlenir. Ekrandaki yanıtın tamamı
korunur. UTF-16 karakter çiftleri bölünmez. Retry anahtarı, gerçekten gönderilen
sınırlı istek gövdesiyle eşleştirilir; aynı retry ikinci kredi tüketmez.

## Doğrulama

- Maven: 249 test, 0 hata/başarısızlık; mevcut koşullu 23 DB/entegrasyon testi
  atlandı. Yeni üretim testleri kaynak ayrımı, sistem rolü, boş/engelli yanıt,
  token limiti retry'si ve ikinci başarısız denemeyi kapsıyor.
- Python: 42 RAG/routing testi geçti. İki eski test fixture'ına eksik zorunlu
  `clarification_needed: false` eklendi; beklenen kaynak/tool reddi artık test
  ediliyor. Üretim router'ı değiştirilmedi.
- Flutter: 161 test geçti. Yeni testler açık/koyu tema, 320 px/%200 yazı,
  Markdown görünümü, kaynak bağlantısı/görsel sınırları, uzun geçmiş ve aynı
  isteğin retry anahtarını kapsıyor. Mevcut sohbet/kredi testleri de geçti.
- `flutter analyze --no-pub`: 0 sorun. `git diff --check`: temiz.
- Markdown sohbeti iki temada render edilerek görsel olarak incelendi.
  Offline önizlemeler Roboto metriklerini kullanır; gerçek cihaz/Inter veya
  canlı üretim yanıtı doğrulaması değildir.

Önizlemeleri yeniden üretmek için `mobile/` altında:

```powershell
flutter test --no-pub --dart-define=CAPTURE_UI=true tool/ui_preview_test.dart --plain-name 'capture assistant'
```

Çıktılar: `mobile/build/ui-previews/assistant-dark.png` ve `assistant-light.png`.
