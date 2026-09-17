class ImageQualityResult {
  const ImageQualityResult({
    required this.suitable,
    required this.code,
    required this.message,
  });

  final bool suitable;
  final String code;
  final String message;

  factory ImageQualityResult.fromJson(Map<String, dynamic> json) {
    return ImageQualityResult(
      suitable: json['suitable'] as bool? ?? false,
      code: json['code'] as String? ?? 'UNKNOWN',
      message:
          json['message'] as String? ??
          'Fotoğraf uygunluğu belirlenemedi. Lütfen tekrar deneyin.',
    );
  }
}
