# Gemini genel erişim ve Hasar Analiz Raporu

26 Ekim 2026. Feature branch: `feature/gemini-general-access-report-ux`.
Güncel `origin/master` temel alındı. Production ayarı değiştirilmedi; deploy,
master merge veya canlı Gemini çağrısı yapılmadı.

## Erişim ve iş kuralları

Backend'deki e-posta izin listesi kaldırıldı. Eski pilot değişkenleri artık
fotoğraf doğrulama, analiz veya rapor tekrarını kısıtlamaz. Kimlik doğrulama,
kayıt/şirket sahipliği, abonelik ve kredi cüzdanı kontrolleri aynı kalır.
Genel erişim ek ücretsiz hak veya sınırsız kullanım oluşturmaz.

Kredi rezervasyonu görsel analizden önce yapılır. Başarılı analiz ve rapor sonunda
tüketim/erişim bir kez kaydedilir. Uygun olmayan veya belirsiz fotoğraf, teknik
hata ve rapor hatası rezervasyonu bırakır. İşlem ve rapor denemesi kimlikleri,
şirket havuzu, iade ve tekrar istek korumaları korunur.

`DAMAGE_ANALYSIS_ENABLED=false` ve başarısız AI readiness yeni görsel analiz ve
fotoğraf doğrulamayı kredi ayırmadan kapatır. Geçmişi okuma ve kayıtlı bulgulardan
yalnız rapor/fiyat aşamasını tekrar deneme mevcut davranışını sürdürür.
Rapor tekrarı görsel analiz çağrısı yapmaz; sunucudaki mevcut rapor/kredi kuralları uygulanır.

## Sonuç ekranı ve PDF

- Tek **Hasar Analiz Raporu**: araç ve tarih, genel şiddet ve maliyet üstte;
  parça, hasar türü, görsel açıklama ve onarım notları birlikte gösterilir.
- Aynı parça tek grupta sunulur. Tarihsel bağımsız hasar/parça listelerinden
  yeni bir eşleşme veya teşhis üretilmez.
- Uzun anlatım Rapor Ayrıntıları altında korunur. Yalnız birebir eşleşen metin
  tekrarları elenir; içerik LLM ile yeniden özetlenmez. Kaynak bilgisi ve tarihsel
  model skoru burada okunabilir. Gemini için güven skoru üretilmez.
- Belirsiz şiddet, parça değişimi belirsizliği, ek fotoğraf yönlendirmesi ve
  uyarılar korunur. Maliyet bulunmadığında sıfır/ücretsiz onarım gösterilmez.
  Eski `NONE` kayıtları görünür hasar bulunmayan tamamlanmış sonuç olarak okunur.
- Rapor hatasında bulgular ekranda kalır; tekrar düğmesi işlem boyunca devre dışıdır.
  Kaybolan HTTP yanıtında önce mevcut durum okunur. Geçmişteki devam eden analiz
  ve raporlar sınırlı süreyle yalnız GET istekleriyle izlenir.
- PDF paylaşımı sonuç ekranından yapılır. PDF aynı içerik kurallarını kullanır;
  görsel bulgu/onarım notları, fiyat açıklaması, kaynak ve uyarıları içerir.
  Fotoğraf kırpılmaz; uzun rapor sayfalara bölünür.
- Hasar Durum Tutanağı ayrı belge olarak kalır. Kesinleşmiş snapshot'lar,
  geçmiş kayıtlar, Gemini şeması, API sözleşmeleri ve veritabanı değişmez.

## Railway değişkenleri

| Ortam | Ayar | Yayın değeri / işlem |
| --- | --- | --- |
| Spring backend | `DAMAGE_ANALYSIS_ENABLED` | Yeni analiz için `true`; bakım için `false` |
| Spring backend | `DAMAGE_ANALYSIS_TEST_ONLY` | Kaldırın; yeni sürüm artık okumaz |
| Spring backend | `DAMAGE_ANALYSIS_TEST_EMAILS` | Kaldırın; yeni sürüm artık okumaz |
| Python AI servisi | `DAMAGE_ANALYSIS_ENABLED` | `true`; `false` görsel analizi ayrıca kapatır |
| Flutter derlemesi | `DAMAGE_ANALYSIS_ENABLED` | Varsayılan `true`; açıkça `false` tanımlanmışsa yeni derlemede `true` yapın |

Sunucudaki `GEMINI_API_KEY`, Gemini model ayarları ve iki serviste eşleşen
`AI_SERVICE_API_KEY` mevcut çalışan yapılandırmada kalır. Bu çalışma bunlar için
yeni değer gerektirmez. Anahtarları mobil uygulamaya taşımayın.

`REVENUECAT_SANDBOX_TEST_CUSTOMER_IDS` gibi ödeme test politikaları bu değişiklikle
ilgili değildir; kaldırmayın. Analiz test listesi ile ödeme sandbox kuralları ayrıdır.

## Yayın sırası

1. Feature branch'i inceleyin, CI kontrollerini tamamlayın ve yayını ayrıca onaylayın.
   Otomatik deploy varsa master'a merge işleminin backend'i yayınlayabileceğini hesaba katın.
2. Kontrollü geçiş için backend'de `DAMAGE_ANALYSIS_ENABLED=false` uygulayın.
   Ardından yeni backend sürümünü dağıtın ve eski iki pilot değişkenini kaldırın.
   Yeni sürüm eski `TEST_ONLY=true` değerini dikkate almaz; kapalı geçiş için genel anahtarı kullanın.
3. Mevcut Python servisinde Gemini readiness ve servis kimliğini doğrulayın;
   `DAMAGE_ANALYSIS_ENABLED=true` olmalı. Python kodu bu çalışmada değişmediği için
   yalnız bu özellik adına yeniden deploy gerekmez.
4. Backend'de `DAMAGE_ANALYSIS_ENABLED=true` uygulayın. Önce normal kişisel hesap
   ve şirket üyesiyle yetki/kredi, yetersiz bakiye, başarılı tek tüketim, hata/iade
   ve rapor tekrarını hedef ortamda doğrulayın. Bu adım gerçek sağlayıcı maliyeti oluşturabilir.
5. Yeni Flutter AAB'yi normal mağaza yayın sürecinden geçirin. Erişim backend
   değişikliğiyle genişler; yeni rapor tasarımı için mobil güncelleme gerekir.
   Çalışma başında mevcut olan `pubspec.yaml` sürüm değişikliği korunmuştur.
6. Gerçek cihazda açık/koyu tema, büyük yazı, geçmiş, PDF paylaşım paneli,
   servis haritası ve ayrı tutanağı kontrol edin. Güncellenmiş uygulama yardım
   belgesini kullanıyorsanız mevcut RAG ingestion sürecini ayrıca uygulayın.

Geri alma: yeni görsel analiz/doğrulamayı durdurmak için backend genel anahtarını
`false` yapın; gerekirse AI servisini de kapatın. Geçmiş kayıtları veya tutanakları
silmek/değiştirmek gerekmez. Eski backend sürümüne dönülürse pilot değişkenleri
yeniden anlam kazanabilir; genel bakım kapısını doğrulamadan açmayın.

## Yerel doğrulama

| Kontrol | Sonuç |
| --- | --- |
| Tüm Java testleri ve gerçek PostgreSQL regresyonları | 312 test; 310 başarılı, Docker isteyen 2 Testcontainers testi atlandı; hata yok |
| Tüm Flutter testleri, PDF ve isteğe bağlı iki tema önizlemesi dahil | 249 başarılı |
| Son analiz/rapor durum metni kontrolü | İlgili 20 widget testi başarılı |
| `flutter analyze --no-pub` | Sorun yok |
| Üretilen PDF'lerin bağımsız `pypdf` metin kontrolü | 5 örnekte bulgu, onarım, maliyet/kaynak, uyarı ve tekrar kontrolü başarılı |
| `git diff --check` | Başarılı |

İlk Flutter koşusunda üç hata bulundu: fotoğraf düğmesinin yeni kaydırma
konumuna göre iki test güncellendi; rapor tekrar düğmesi istek boyunca görünür
ve devre dışı kalacak şekilde düzeltildi. Son tam paket başarılıdır.

PostgreSQL 18 test kümesi bu çalışma için ignored `target/gemini-report-postgres`
altında oluşturuldu ve yalnız `127.0.0.1:55440` üzerinden kullanıldı. Üç ayrı,
silinebilir test veritabanında kredi/şirket paylaşımı, iade, işlem tekrarı,
eşzamanlılık, sahiplik ve geçmiş kayıt regresyonları çalıştı. Uygulama veya
production veritabanına bağlanılmadı; test sunucusu çalışma sonunda durduruldu.
Atlanan testler `AiAssistantBusinessConcurrencyIT` ve `AiAssistantServiceConcurrencyIT`.

Eklenen kontroller: eski pilot ve normal e-postanın aynı ücretli akışa girmesi,
eski pilot yapılandırmasının artık kısıt oluşturmaması, kapalı bakım anahtarında
hiçbir görsel isteğin çıkmaması, kredi olmadan fotoğraf doğrulamasının engellenmesi;
parça bazında birleşme, tarihsel eşleşme uydurmama, belirsiz/ek fotoğraf durumları,
rapor hatası/tekrar, geçmişte devam eden analiz, 320 pikselde büyük yazı ve iki tema.

Tekrar çalıştırma (`mobile` içinde):

```powershell
flutter test --no-pub --dart-define=WRITE_REPORT_PREVIEWS=true
flutter analyze --no-pub
```

Backend için repo kökünde, önceden hazırlanmış **silinebilir** test veritabanlarıyla:

```powershell
.\mvnw.cmd -B '-Dtest=*Test,*IT' '-Dcredit.test.jdbc-url=jdbc:postgresql://127.0.0.1:55440/credit_system_test' '-Dcredit.test.username=report_test' '-Dinspection.test.jdbc-url=jdbc:postgresql://127.0.0.1:55440/vehicle_inspector_test' '-Dinspection.test.username=report_test' '-Dsecurity.test.jdbc-url=jdbc:postgresql://127.0.0.1:55440/security_audit_test' '-Dsecurity.test.username=report_test' test
```

Ham loglar ignored `target/gemini-report-*.log`; tema PNG'leri ve beş PDF örneği
`mobile/build/report-previews/` altındadır. PDF metin kontrolünde yeni raporun aynı
görsel açıklamayı bir kez yazdığı, güvenlik notu/kaynak/fiyatın korunduğu ve 35
bulgunun uzun belgede kaybolmadan sayfalara dağıldığı ayrıca doğrulandı.

Gerçek Gemini kalitesi/faturası, Railway yapılandırması, fiziksel cihazdaki
paylaşım paneli/harita ve mağaza yayını yerel testlerin kapsamında değildir.
