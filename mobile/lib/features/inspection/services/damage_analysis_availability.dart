/// Server readiness and credentials control Gemini availability.
class DamageAnalysisAvailability {
  static bool get available =>
      const bool.fromEnvironment('DAMAGE_ANALYSIS_ENABLED', defaultValue: true);

  static const message =
      'Hasar analizi geçici olarak kullanılamıyor. '
      'Mevcut analiz ve raporlarınıza erişebilirsiniz.';
}
