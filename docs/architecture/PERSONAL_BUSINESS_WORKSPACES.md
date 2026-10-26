# Kişisel ve şirket çalışma alanları

Branch: `feature/personal-business-workspaces`. Mevcut `master` temel alınmıştır.
İkinci kullanıcı/oturum, yeni tablo, Flyway migration, bağımlılık veya Railway
servisi eklenmez. Araçlar, geçmiş kayıtlar ve kredi ledger'ı taşınmaz.

## İstek sözleşmesi

Yeni istemci, oturum token'ıyla birlikte `X-Workspace: PERSONAL` veya `BUSINESS`
gönderir. Şirket kimliği gönderilmez; sunucu mevcut üyelikten çözer. Aynı kullanıcı
iki alana da yetkiliyse kaynak ID'sinin seçili alanla eşleşmesi ayrıca zorunludur.
Yanlış alanın araç, bakım, kilometre, analiz, rapor, fotoğraf ve tutanak istekleri
404; yetkisiz şirket seçimi 403; geçersiz/çoklu workspace header'ı 400 alır.

`GET /api/v1/workspace`, doğrulanan `type`, `userId`, `businessId` değerlerini döndürür.
Switcher geçişten önce bu uçla üyeliği doğrular. Başarılı veri yanıtı `X-Workspace`
başlığıyla alanı onaylar. Flutter eksik/uyuşmayan onayı kabul etmez; eski backend'in
şirket verisini kişisel alan etiketiyle göstermek yerine erişimi güvenle durdurur.
CORS, istek ve yanıt başlığını destekler.

Header göndermeyen eski mobil sürümlerde üyeler BUSINESS, diğer kullanıcılar
PERSONAL kullanır. Eski kredi ekranının iki hesaplı yanıtı ve SKU ile hedef
seçme davranışı korunur. Yeni `/credits` isteği yalnız seçili hesabı yükler;
`personal` veya `company` alanlarından seçilmeyen `null` olur.

`/auth/**` kimlik ve üyelik metadatasıdır; aktif alandan bağımsızdır. Böylece
üyelik kaldırılmışken `/auth/me` yine kişisel hesaba dönüş için kullanılabilir.
Şirket üyeliği/şirket oluşturma ve ödeme uzlaştırma, mevcut kimlik/OWNER/SKU
kurallarını kullanır; workspace seçimi bu hakları yaratmaz veya yükseltmez.
Webhook ve zamanlanmış işler mobil tercihe göre çalışmaz.

## Backend sınırları

- `WorkspaceContext` immutable bir istek kimliğidir. `WorkspaceResolver` bunu
  yalnız mevcut servlet isteğinin attribute'unda tutar. Paylaşılan mutable kullanıcı
  seçimi veya uygulamaya ait workspace ThreadLocal'ı yoktur. Spring'in request
  erişimi kullanılır; farklı HTTP istekleri/cihazlar birbirinin seçimini değiştiremez.
- `WorkspaceWebConfig` kimliği doğrulanmış veri isteklerini doğrular. Context ilk
  çözümde sabitlenir; şirket üyeliğinin kaybolması/başka şirkete dönüşmesi sonradan
  yeniden doğrulandığında reddedilir. Devam eden istek başka havuza yönlenmez.
- `BusinessContextService.findMembership` gerçek hesap üyeliğidir; auth ve şirket
  yönetimi bunu kullanır. `findWorkspaceMembership`, `isBusinessWorkspace` ve
  `workspace` seçili veri alanına aittir. Açık PERSONAL seçiminde gereksiz şirket
  üyelik sorgusu yapılmaz. BUSINESS için güncel üyelik korunur.
- Araç, inceleme, tracking ve asistan tool erişimleri bu ayrımı kullanır.
  Mevcut aktif abonelik gereken işlemler aktif abonelik istemeye devam eder;
  tarihsel raporların üyelikle okunması gibi mevcut kurallar değiştirilmez.
- Bildirim listesi, okunmamış sayısı ve okundu işlemleri kullanıcı + alanla
  filtrelenir. Kişisel araç bildirimleri şirket ekranına, şirket bildirimleri kişisel
  ekrana karışmaz. Üyeliği bitenin eski şirket bildirimleri görünmez.
  Push gönderiminde güncel şirket üyeliği yeniden kontrol edilir. Zamanlanmış
  hatırlatmalar araç sahipliği/gerçek üyelik üzerinden çalışmaya devam eder.

## Kredi ve ödeme bütünlüğü

`CreditWalletService` içindeki `user:{id}` ve `business:{id}`, rezervasyon token'ı,
advisory/account kilitleri, dönemlik/kalıcı bakiye, iade borcu, webhook doğrulaması
ve idempotency korunur. Kişisel kullanım yalnız kişisel, şirket kullanımı yalnız
ortak cüzdanı tüketir; yetersiz bakiyede diğer cüzdan denenmez.

Kredi tamamlama ve kayıtlı asistan yanıtını yeniden okuma rezervasyonun hesap
yetkisini tekrar doğrular. Tamamlama sırasında üyelik satırı paylaşım kilidiyle
korunur; eşzamanlı üyelik silme tüketimle seri hale gelir. Üye çıkarılmışsa tüketim
reddedilir. Release, güncel workspace'ten bağımsız olarak token'ın orijinal
cüzdanına iade yapabilir. Süre/dönem değişimine ilişkin mevcut kurallar korunur.

Yeni satın alma niyetinin ürün türü seçili alanla eşleşmelidir. MEMBER kişisel
paket alabilir, şirket adına alamaz. OWNER iki alanını da kullanabilir; Business
aboneliği sahibine kişisel alanda şirket kotası vermez. Şirkete katılmak kişisel
planı, satın alma kayıtlarını veya kalıcı kredileri değiştirmez.

Satın alma/iadede hedef, orijinal intent/transaction ve doğrulanmış RevenueCat
kimliğidir. Mobilde alan değişmesi pending purchase veya webhook'u başka cüzdana
taşımaz. SKU'lar, fiyatlar ve RevenueCat customer ID modeli değişmez.

Flutter ödeme akışı da başlangıçtaki oturum/alanı sabitler: gecikmiş mağaza cevabı
yeni kullanıcının token'ıyla sync/confirmation başlatmaz. Başlamış mağaza işlemi
workspace değişince otomatik yeniden denenmez; kabul edilmiş ödeme orijinal
hesapta webhook/uzlaştırmayla tamamlanabilir. Native RevenueCat identity
yapılandırmaları, eski login'in yenisinden sonra bitmesini önlemek için sıralanır.

## Flutter davranışı

Switcher ana uygulamada kolay erişilebilen bir bileşendir; üye olmayanlarda gizlidir.
Kişisel/şirket seçimi kullanıcı ID'siyle güvenli depoda tutulur. Üyelik kalkarsa
geçersiz tercih PERSONAL olarak düzeltilir. Çıkışta bellek seçimi temizlenir;
başka kullanıcının tercihi, token'ı veya cache'i devralınmaz.

`ApiClient` JSON, binary ve multipart işlemlerinde başlangıç scope'unu yakalar.
Token okunurken veya istek sürerken alan/oturum değişirse gönderim ya da yanıt
kullanımı durdurulur. Eski 401, sonraki kullanıcının oturumunu kapatamaz.
`WORKSPACE_UNAVAILABLE` yanıtında kişisel alana dönülür; token silinmez.
Hesap bilgisi uygulama yeniden ön plana geldiğinde de yenilenir.

`MainShell` alan değişiminde ekran cache'ini ve subtree kimliğini yeniler;
eski alanın açık route'larını kapatır. Görsel lifetime döndürülür; mevcut image
cache ve decoded görüntüler temizlenir. Asistan ekranı/conversation state'i
de yeniden oluşturulur. Kullanılmayan alanın bütün sekmeleri önceden yüklenmez.
Kredi ekranı ana seçimi izler; ikinci bağımsız kişisel/şirket selector'ı yoktur.

İki fotoğraflı Gemini çağrısı, rapora özel tekrar ve RAG/generation mantığı değişmez.
Switcher'ın doğrulama GET'i veya alan değişimi LLM isteği başlatmaz.

## Yayın ve rollback

1. Branch/CI incelemesi ve merge ayrı onayla yapılmalıdır; bu çalışma merge,
   production deploy, Railway ayarı veya canlı ödeme/AI çağrısı içermez.
2. Önce backend'i dağıtın. Mevcut PostgreSQL şeması yeterlidir; yeni migration,
   indeks, servis veya ortam değişkeni yoktur. Proxy/gateway varsa `X-Workspace`
   başlığını her iki yönde koruduğunu doğrulayın. Mobil yayından önce bütün
   backend replikalarının yeni sözleşmeyi desteklediğini kontrol edin.
3. Eski istemciyi header olmadan test edin. Yeni istemciyle PERSONAL/BUSINESS,
   OWNER/MEMBER, yetersiz kredi, üyelik iptali ve abonelik bitişini doğrulayın.
4. Flutter build numarasını yayın sürecinizde artırın; yeni AAB/mağaza yayını yapın.
   Bu çalışma mevcut `mobile/pubspec.yaml` sürümünü değiştirmez.
5. Güncellenmiş yardım belgesini RAG'de kullanıyorsanız mevcut ingestion sürecini
   ayrıca çalıştırın; burada production ingestion yapılmaz.

UI rollback backend workspace sınırını kaldırmayı gerektirmez. Yeni mobil sürüm
kullanılırken backend'i header'ı yok sayan eski sürüme döndürmeyin; Flutter veri
yanıtlarını onaysız kabul etmeyeceğinden yeni istemciler erişim hatası gösterir.
Forward fix veya workspace sözleşmesini koruyan backend rollback tercih edin.
Veriler taşınmadığından veri geri taşıma/migration rollback'i yoktur.
Yanıt başlığı kontrolü, isteği almış eski bir sunucudaki yan etkiyi geri alamaz;
eski backend veya workspace başlığını silen proxy ile yeni istemci birlikte
kullanılmamalıdır. Bu nedenle tam backend geçişi ve proxy kontrolü yayın ön koşuludur.

## Yerel doğrulama ve sınırlar

| Kontrol | Sonuç |
| --- | --- |
| Maven + gerçek PostgreSQL testleri / JAR package | 334 test, 332 başarılı; Docker isteyen 2 test atlandı; build başarılı |
| Flutter tam test paketi | 263 başarılı |
| Son güvenli alan/rehber/workspace kontrolleri | İlgili 31 test başarılı |
| Flutter statik analiz | Sorun yok |
| Android debug APK | Başarılı; production yayını değildir |

Atlananlar: `AiAssistantBusinessConcurrencyIT` ve `AiAssistantServiceConcurrencyIT`;
yerel ortamda Docker bulunmadığından Testcontainers bunları çalıştırmadı.

SQL testleri yalnız bu çalışma için kullanılan `127.0.0.1:55440` test kümesindeki
`credit_system_test`, `vehicle_inspector_test`, `security_audit_test` veritabanlarında
çalışır; uygulama veritabanına bağlanılmaz. Test sunucusu sonunda durdurulur.
Loglar ignored `target/workspace-*.log`; APK `mobile/build/app/outputs/flutter-apk/app-debug.apk`.

Testler; eski istemci varsayılanını, sahte/çoklu header'ları, request izolasyonunu,
kişisel/şirket araç/rapor/fotoğraf ve asistan tool sınırını, doğru havuz tüketimini,
üye çıkarılınca completion reddini ve orijinal havuza iadeyi, niyet/webhook/refund
hedefini, geç cevap/401/cache izolasyonunu, kullanıcıya bağlı tercihi, ödeme sırasında
alan/kullanıcı değişimini ve 320 px / 2x yazıda dark/light switcher'ı kapsar.

Manuel kontrol: gerçek cihazda mağaza ödeme paneli, pending purchase/restore ve
kullanıcı değişimi; FCM ve üyelik iptali; uzun şirket adları ve ekran okuyucu;
gerçek Railway/proxy başlık aktarımı. Yerel mock'lar gerçek Gemini kalitesi,
mağaza ödeme kabulü veya üretim faturası kanıtı değildir. Daha önce indirilmiş veri
ve teslim edilmiş OS push bildirimi uzaktan anında silinmez; server yeni erişimi
reddeder, istemci iptali öğrendiğinde cache'i ve açık ekranları temizler.

Tekrar: `flutter test --no-pub`, `flutter analyze --no-pub`, `flutter build apk --debug --no-pub`.
Maven: `mvnw.cmd -B '-Dtest=*Test,*IT' package`; SQL testleri için yukarıdaki
disposable veritabanlarına `credit.test.jdbc-url`, `inspection.test.jdbc-url`,
`security.test.jdbc-url` ve ilgili username özelliklerini açıkça verin.
