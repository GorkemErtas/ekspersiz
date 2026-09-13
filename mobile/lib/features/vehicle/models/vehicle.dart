class Vehicle {
  const Vehicle({
    required this.id,
    required this.plate,
    required this.brand,
    required this.model,
    required this.modelYear,
    required this.mileage,
    required this.primaryVehicle,
  });

  final int id;
  final String plate;
  final String brand;
  final String model;
  final int modelYear;
  final int mileage;
  final bool primaryVehicle;

  String get displayName => '$brand $model';

  factory Vehicle.fromJson(Map<String, dynamic> json) {
    return Vehicle(
      id: (json['id'] as num?)?.toInt() ?? 0,
      plate: json['plate'] as String? ?? '',
      brand: json['brand'] as String? ?? '',
      model: json['model'] as String? ?? '',
      modelYear: (json['modelYear'] as num?)?.toInt() ?? 0,
      mileage: (json['mileage'] as num?)?.toInt() ?? 0,
      primaryVehicle: json['primaryVehicle'] as bool? ?? false,
    );
  }
}
