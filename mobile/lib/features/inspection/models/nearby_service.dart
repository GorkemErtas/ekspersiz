class NearbyService {
  const NearbyService({
    required this.placeId,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.rating,
    required this.userRatingCount,
    required this.primaryType,
    required this.googleMapsUri,
    required this.distanceKm,
  });

  final String placeId;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final double? rating;
  final int? userRatingCount;
  final String? primaryType;
  final String? googleMapsUri;
  final double distanceKm;

  factory NearbyService.fromJson(Map<String, dynamic> json) {
    return NearbyService(
      placeId: _parseString(json['placeId']),
      name: _parseString(json['name']),
      address: _parseString(json['address']),
      latitude: _parseDouble(json['latitude']),
      longitude: _parseDouble(json['longitude']),
      rating: _parseNullableDouble(json['rating']),
      userRatingCount: _parseNullableInt(json['userRatingCount']),
      primaryType: _parseNullableString(json['primaryType']),
      googleMapsUri: _parseNullableString(json['googleMapsUri']),
      distanceKm: _parseDouble(json['distanceKm']),
    );
  }

  static String _parseString(dynamic value) {
    if (value == null) {
      return '';
    }

    return value.toString().trim();
  }

  static String? _parseNullableString(dynamic value) {
    if (value == null) {
      return null;
    }

    final parsed = value.toString().trim();

    return parsed.isEmpty ? null : parsed;
  }

  static double _parseDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double? _parseNullableDouble(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value.toString());
  }

  static int? _parseNullableInt(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value.toString());
  }
}
