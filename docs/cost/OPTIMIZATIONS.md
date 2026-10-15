# Railway maliyet ve bellek optimizasyonları

**Tarih:** 15 Ekim 2026 · **Durum:** PR #7 ve #9 merge edildi; sonraki kod denetiminde gereksiz/riskli parçaları geri alma kararı verildi. Aşağıdaki uygulama tablosu denetim değişiklikleri merge edildikten sonraki hedef durumu belirtir.

Bu belge bir **mimari karar ve ölçüm kaydıdır**; aylık fatura tasarrufunun doğrulandığı anlamına gelmez. Teknik deney ayrıntıları için [başlangıç maliyetleri](BASELINE_2026-10-15.md) ve [heap temizleme deneyi](AI_HEAP_RECLAIM_2026-10-15.md) belgelerine bakın.

## Başlangıç referansı (Railway)

15 Ekim 2026 ekran görüntülerindeki kullanım yaklaşık **bir aylık** dönemi kapsıyor; kesin fatura başlangıç/bitiş saatleri ve karşılaştırılabilir istek sayıları bilinmiyor.

| Kaynak | Tutar |
| --- | ---: |
| Spring Boot backend | **$0.9978** |
| FastAPI AI | **$0.5909** |
| PostgreSQL | **$0.1602** |
| **Toplam** | **~$1.75** |

Kaynak türüne göre bellek maliyeti **$1.6581 (~%94,8)**, CPU **$0.0769**, disk **$0.0122**, egress **$0.0011**. Kaynak maliyetleri gerçek zamanlı ölçümlerin birikimidir; tek bir RAM zirvesi aylık maliyet olarak yorumlanamaz.

## Üretime alınan değişiklikler

| Katman | Uygulama | Amaç / ödünleşim |
| --- | --- | --- |
| FastAPI / YOLO | Üç YOLO modeli ilk görüntü isteğinde, kilitle korunarak **tek kez** yükleniyor | Asistan/health isteklerinde vision modelleri boştayken yüklenmez; **ilk görüntü isteği yavaşlayabilir**, ilk yüklemeden sonra modeller bellekte kalır |
| FastAPI / inference | CPU ağırlıklı işlemler event loop dışında işleniyor; inference kilidi aynı anda **tek YOLO işlemi** çalıştırıyor | Eşzamanlı bellek tahsisini azaltır, yoğun trafikte **bekleme süresini artırabilir** |
| AI Asistan / RAG | E5 embedding modeli ve retriever ilk kullanımda tek kez oluşturuluyor | Eşzamanlı ilk isteklerde çift model yüklemesini önler |
| Görüntü | Yükleme okuması **10 MiB + 1 byte** ile sınırlı; gereksiz ikinci RGB kopyası kaldırıldı; OpenCV Laplacian hesabı önceki **float64** hassasiyetine döndürüldü | Geçici RAM kullanımı azaltılırken fotoğraf uygunluk eşiğinin sayısal davranışı korunur |
| Python imajı | GUI OpenCV kaldırıldıktan sonra headless OpenCV zorunlu yeniden kuruluyor | Eksik `cv2` binary kurulumlarını engeller |
| Spring Boot | JVM varsayılanı `-Xms128m -Xmx768m` korunuyor; HikariCP havuzu, ölçülmüş tasarruf olmadığı için Spring Boot varsayılanlarına döndürüldü | JVM üst sınırı hâlâ gerçek yük altında izlenmelidir; veritabanı havuzu gereksiz küçültülmez |

Bunlar var olan API yolları, veritabanı şeması, model ağırlıkları, abonelik/kota iş kuralları veya hasar eşikleri değiştirilmeden yapıldı.

**Uygulama geçmişi:** [PR #7](https://github.com/GorkemErtas/ekspersiz/pull/7) → `6597675`; [PR #9](https://github.com/GorkemErtas/ekspersiz/pull/9) → `3d15402`. Her iki PR **normal merge** ile birleştirildi.

## Denenip geri alınan değişiklikler

- **Linux heap temizliği (`AI_TRIM_HEAP_AFTER_INFERENCE`):** Sentetik testte kullanılmayan bellek sayfalarını geri verebildi; ancak gerçek uygulamada analizin birden fazla aşamasında çalışması ve AI Asistan ile aynı süreci paylaşması nedeniyle **üretimde hiç açılmadı**. Kullanılmayan özel modül, tetikleyici ve buna özgü CI benchmark yükü kaldırılıyor. Testlerin tarihsel raporu [burada](AI_HEAP_RECLAIM_2026-10-15.md).
- **HikariCP maksimum 5 / minimum idle 1:** PostgreSQL maliyeti düşük, eşzamanlı bağlantı kısıtlamasının faydası doğrulanmadı; varsayılan bağlantı havuzu davranışına dönülüyor.
- **OpenCV float32 netlik hesabı:** Sınırlı geçici RAM kazancı olasılığına karşı görüntü kalite eşiklerine yakın sayısal sapma riski vardı. Orijinal float64 işlemi geri getiriliyor.
- **CPU thread sayısını azaltma:** PR #8 deneyinde tepe RAM kazancı tekrarlanamadı; kodu üretime hiç alınmadı.
- **AI Serverless:** İlk analiz hatası nedeniyle kapalı tutuldu; yeniden açılmıyor.

## Ölçülen sonuçlar: CI ile üretim verisini ayırma

| Test / ölçüm | Sonuç | Sınır |
| --- | --- | --- |
| Gerçek YOLO ağırlıkları ve sentetik büyük fotoğraflar, 3 tekrar / koşul | Trim kapalı **590,9 MiB**, açık **467,2 MiB** işlem sonrası RSS medyanı (**-%20,9**) | GitHub Actions CPU ortamı; **üretim maliyet tasarrufu değil** |
| Son tekrarlı benchmark | **640,2 → 478,6 MiB** retained RSS medyanı | CI örneği; fotoğraf özellikleri gerçek kullanımda değişir |
| Sentetik kalite kontrolü gecikmesi | Örneğin **150 ms → 161 ms** medyan | Trim açıkken az da olsa gecikme artabilir |
| Gerçek hasar analizi, Railway | Kullanıcının eski/yeni sürüm analizlerinin aynı sonuçları verdiği ve HTTP 200 ile tamamlandığı görüldü | Fotoğraf seti ve eşzamanlı yük kapsamlı doğrulanmadı |
| AI servisinde analiz sonrası RAM | Önceki sürümde **~1,28 GB**, `3d15402` sonrasında **~675 MB** görüldü | **Eşit süre/aynı işlem geçmişi değil**; trim etkin değildi ve bu düzeyin kalıcı tasarruf olduğu doğrulanmadı |

**Testler:** [GitHub Actions CI](https://github.com/GorkemErtas/ekspersiz/actions/runs/38781613103) başarılı. Eski `master` üzerinde 90 Python testi: **87 geçti, 2 failure + 1 error**; PR #9 üzerinde 95 test: **92 geçti, aynı 3 önceden var olan sorun**. Yeni regresyon **0**; bu, tam Python paketinin hatasız olduğu anlamına **gelmez**. Maven CI çalışmasında **157 başarılı, 10 atlanan** test kaydedildi. Üretim yük testi ve gerçek kullanıcı p95 gecikmesi ayrıca doğrulanmalı.

## Kararlar, izlenecek metrikler ve geri dönüş

- **Şu an:** AI Serverless **kapalı**, deneysel heap trim işlevi **koddan kaldırıldı**. Çalışan modeli otomatik boşaltmak, modeli küçültmek, GPU eklemek, Redis/RabbitMQ gibi ek hizmetler veya ekstra veritabanı eklemek planlanmadı.
- **Bir sonraki karşılaştırma:** Aynı fotoğraflar ve benzer trafik koşullarında servis başına **RAM GB-dakika**, CPU vCPU-dakika, analiz süresi (özellikle p95), ilk istek süresi, istek sayısı, HTTP 5xx/OOM ve analiz sonucu. Süreleri eşit tutmadan faturadaki toplam dolar tutarlarını doğrudan karşılaştırmayın.
- **Kontrol edilecek riskler:** JVM'de native RSS/GC, Hikari havuzunda bağlantı beklemesi, ilk YOLO yüklemesi, tek inference kilidinin kuyruk süresi, AI Asistan ile aynı süreçte eşzamanlı talep. Serverless backend üzerindeki zamanlanmış görevlerin çalışabilirliği ayrıca izlenmelidir.
- **Geri dönüş:** Yeni dağıtım bir sorun yaratırsa Railway'deki son başarılı sürüme rollback yapılabilir. Her değişiklikten sonra log ve gecikmeler kontrol edilir.

Belgede üretimden alınan anlık RAM değerleri ve sentetik CI benchmark'ları **ayrı tutulur**. **Doğrulanmış aylık tasarruf oranı yoktur.**

## Kod denetimi ve sadeleştirme

Kod denetiminde öncelik, kullanıcının mevcut iş akışlarını ve canlı analiz doğruluğunu korumaktır. İşe yaradığı doğrulanmamış veya etkin olmayan ek optimizasyonlar otomatik olarak kalıcı mimari unsuru kabul edilmez. Geri alınan parçaların nedenleri yukarıda tutulur; önceki deneylerin CI sonuçları tarihsel kanıt niteliğindedir.
