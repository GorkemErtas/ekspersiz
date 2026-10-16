# EksperSiz — Flutter Mobil Uygulaması

EksperSiz'in Flutter/Dart istemcisi. Araç yönetimi, YOLO tabanlı hasar analizine fotoğraf gönderme, Gemini raporlarını görüntüleme, AI Asistan, hatırlatmalar, kurumsal hesaplar ve abonelik arayüzünü içerir.

## Özellikler
- E-posta/şifre ve Google oturumu; güvenli token saklama, profil ve hesap işlemleri.
- Araç kaydı, bakım/kilometre, hatırlatmalar, analiz geçmişi ve raporlar.
- Fotoğraf seçimi, hasar analizi, değerlendirme tutanağı ve PDF paylaşımı.
- AI Asistan: yazılı sohbet, Türkçe konuşmadan metne giriş, araç bağlamı, günlük hakların görüntülenmesi.
- FREE/PLUS/PRO/BUSINESS planları ve RevenueCat satın alma akışı; FREE planda ayda 1 analiz ve günde 3 AI Asistan yanıtı.
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
