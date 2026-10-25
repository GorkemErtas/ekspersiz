enum GuideFeature { welcome, analysis, reports, garage, assistant, credits }

class OnboardingStep {
  const OnboardingStep({
    required this.feature,
    required this.category,
    required this.title,
    required this.description,
    required this.hint,
  });

  final GuideFeature feature;
  final String category;
  final String title;
  final String description;
  final String hint;
}

const onboardingSteps = [
  OnboardingStep(
    feature: GuideFeature.welcome,
    category: 'EKSPERSİZ’E HOŞ GELDİN',
    title: 'Aracını tanı.\nYoluna güvenle çık.',
    description:
        'Hasarı anlamaktan bakımı takip etmeye, aracınla ilgili '
        'bilgileri tek yerde topla. EksperSiz ile ilk adımı birlikte atalım.',
    hint: 'Kaydır, keşfet, hazır olduğunda başla.',
  ),
  OnboardingStep(
    feature: GuideFeature.analysis,
      category: 'İKİ FOTOĞRAF · AI ANALİZİ',
      title: 'İki fotoğrafla\nhasarı anlamaya başla.',
    description:
          'Aracını seç; hasarın genel görünümünü ve yakın detayını yükle. '
          'AI, aynı bölgenin iki fotoğrafındaki görünür bulguları birlikte yorumlasın.',
    hint: 'Ana Sayfa → Yeni Analiz Başlat',
  ),
  OnboardingStep(
    feature: GuideFeature.reports,
    category: 'RAPORLAR VE GEÇMİŞ',
    title: 'Detayları gör.\nGeçmişine dön.',
    description:
        'Hasar tespitlerini ve hazır olduğunda detaylı AI raporunu '
        'incele. Önceki sonuçlarına Analizler sekmesinden yeniden ulaş.',
    hint: 'AI değerlendirmesi, fiziksel ekspertizin yerini tutmaz.',
  ),
  OnboardingStep(
    feature: GuideFeature.garage,
    category: 'ARACININ DİJİTAL GARAJI',
    title: 'Bakımını planla.\nAklında kalmasın.',
    description:
        'Aracını ekle, kilometresini ve bakım kayıtlarını güncel tut. '
        'Muayene, sigorta ve bakım için hatırlatmalar oluştur.',
    hint: 'Araçlar → Araç detayı → Bakım ve hatırlatmalar',
  ),
  OnboardingStep(
    feature: GuideFeature.assistant,
    category: 'SORULARINDAN SONRAKİ ADIMA',
    title: 'Asistanına sor.\nServisleri keşfet.',
    description:
        'Araç ve bakım sorularını AI Asistan’a sor. Analiz '
        'sonucundan konumuna yakın uygun servisleri incele.',
    hint: 'Ana Sayfa → AI Asistan · Analiz Sonucu → Servisler',
  ),
  OnboardingStep(
    feature: GuideFeature.credits,
    category: 'İHTİYACINA GÖRE KULLAN',
    title: 'Kredilerin sende.\nEkibin de yanında.',
    description:
        'Analiz ve asistan için ayrı kredi bakiyelerini, paketleri '
        've araç kapasiteni yönet. Kurumsal hesapta araçlar, analizler ve '
        'şirket kredileri yetkilerin doğrultusunda ortak kullanılır.',
    hint: 'Profil → Krediler ve Paketler · Uygulama Rehberi',
  ),
];
