# EksperSiz AI Asistan Veri ve Gizlilik Mimarisi

Bu doküman uygulamanın AI Asistan özelliğinin teknik veri akışını açıklar; hukuki gizlilik politikası yerine geçmez.

## Private knowledge base
Vector knowledge base yalnız EksperSiz'e özel ve kamuya açık web'den güvenilir biçimde elde edilemeyen ürün bilgileri için kullanılır. Uygulama kılavuzu, AI Asistan davranışı ve uygulamanın veri işleme mimarisi bu kapsamdadır.

## Kullanıcı verileri
Kullanıcının kişisel araç kayıtları, hasar analiz geçmişi ve hatırlatmaları embedding oluşturmak için kullanılmaz ve private vector knowledge base'e yazılmaz.

AI Asistan kullanıcının kendi kayıtlarına ihtiyaç duyduğunda backend, oturum açmış kullanıcının yetkisini doğrular ve gerekli veriyi güvenli araçlar üzerinden anlık olarak sağlar. Model kullanıcı kimliği veya SQL sorgusu seçmez.

## Seçili araç bağlamı
Kullanıcı AI Asistan ekranında bir araç seçtiğinde planner'a yalnız cevap için gerekli güvenli araç özeti gönderilebilir: marka, model ve model yılı. Plaka ve serbest metin notları planner bağlamına dahil edilmez.

## Kamuya açık bilgi
Araç teknik özellikleri, bakım değerleri, üretici bilgileri ve diğer kamuya açık otomotiv bilgileri private knowledge base'e gömülmez. Bu sorular kamuya açık kaynaklarla grounding yapılan Gemini akışına yönlendirilir.

## Kapsam kontrolü
AI Asistan otomotiv ve EksperSiz kullanım alanıyla sınırlandırılır. Kapsam dışı istekler cevap üretiminden önce semantic routing aşamasında reddedilir.
