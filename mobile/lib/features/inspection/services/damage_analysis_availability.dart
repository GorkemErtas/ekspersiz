/// Keep new image operations disabled until a damage provider is integrated.
class DamageAnalysisAvailability {
  static bool get available => false;

  static const message =
      'Hasar analizi geçici olarak kullanılamıyor. '
      'Mevcut analiz ve raporlarınıza erişebilirsiniz.';
}
