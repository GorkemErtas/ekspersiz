# EksperSiz — Flutter Mobil Uygulaması

EksperSiz'in Flutter/Dart istemcisi. Araç yönetimi, geçmiş hasar analizlerini görüntüleme, Gemini raporlarını görüntüleme, AI Asistan, hatırlatmalar, kurumsal hesaplar ve abonelik arayüzünü içerir.

## Özellikler
- E-posta/şifre ve Google oturumu; güvenli token saklama, profil ve hesap işlemleri.
- Araç kaydı, bakım/kilometre, hatırlatmalar, analiz geçmişi ve raporlar.
- Genel görünüm ve yakın detay fotoğraflarıyla tek Gemini analizi; parça bazında bulgu/onarım ve tahmini maliyeti birleştiren Hasar Analiz Raporu.
- Rapordan PDF paylaşımı, yakındaki servisler ve ayrı Hasar Durum Tutanağı.
- AI Asistan: yazılı sohbet, Türkçe konuşmadan metne giriş, araç bağlamı, günlük hakların görüntülenmesi.
- Mevcut planlar, kişisel/şirket kredi cüzdanları ve RevenueCat satın alma akışı; kullanım hakkını backend doğrular. [Kredi kuralları](../docs/billing/CREDIT_SYSTEM.md).
- Harita/yakındaki servisler, bildirimler/FCM, tema, yerelleştirme ve Android uygulama içi güncelleme kontrolü.

## Mimari
- `lib/core/`: ağ, kimlik doğrulama/oturum, tema, yerelleştirme ve ortak altyapı.
- `lib/features/`: ekranlar, modeller ve özellik bazlı servisler.
- Mobil uygulama Spring Boot REST API'siyle haberleşir; AI modelleri ve ödeme yetkilendirmesi cihazda çalışmaz, backend'de yönetilir.

## Geliştirme
Gereksinimler: projedeki `pubspec.yaml` ile uyumlu Flutter/Dart SDK, Android SDK ve ilgili Google/Firebase/RevenueCat yapılandırmaları.

```bash
cd mobile
flutter pub get
flutter run
flutter test
flutter analyze
```

Android sürüm/build numarası `pubspec.yaml` içindeki `version` alanındadır. Yayınlama ve imzalama işlemleri için Google Play Console yapılandırması gerekir. Gizli anahtarları repoya eklemeyin.

Ana proje ve backend bilgileri için [kök README](../README.md) dosyasına bakın.

Analiz tüm uygun hesaplara açıktır; test e-postası listesi kullanılmaz. Bu erişim ücretsiz veya sınırsız kullanım hakkı vermez. İki fotoğraf tek görsel çağrıda değerlendirilir; uygunluk kontrolleri ek Gemini çağrısı yapmaz. Rapor hatasında yalnız rapor/fiyat aşaması tekrar denenir.

`DAMAGE_ANALYSIS_ENABLED` mobil derleme bayrağı varsayılan `true` değerindedir. Sunucudaki aynı isimli bakım anahtarı bağımsızdır ve yeni mobil derleme beklemeden analiz/doğrulamayı kapatır. Mevcut geçmiş raporları okunabilir. API anahtarları mobil uygulamaya konmaz.

Belirsiz şiddet ve parça değişimi belirsiz kalır; yeni Gemini sonuçları için güven yüzdesi gösterilmez. Ek fotoğraf yönlendirmesi, bulgu/onarım notları ve uyarılar korunur; tekrar eden uzun anlatım Rapor Ayrıntıları altında açılır. Eski kayıtlar ve kesinleşmiş tutanaklar değiştirilmez.

[Gemini sözleşmesi](../docs/GEMINI_VISION_ANALYSIS.md) · [Genel erişim ve yayın sırası](../docs/GEMINI_GENERAL_ACCESS_REPORT_UX.md).
