/// Server readiness and credentials control Gemini availability.
class DamageAnalysisAvailability {
  static bool get available => const bool.fromEnvironment(
    'DAMAGE_ANALYSIS_ENABLED',
    defaultValue: true,
  );

  static const message =
      'Hasar analizi geÃ§ici olarak kullanÄ±lamÄ±yor. '
      'Mevcut analiz ve raporlarÄ±nÄ±za eriÅŸebilirsiniz.';
}
