import '../../../core/network/api_client.dart';
import '../models/vehicle.dart';

class VehicleService {
  const VehicleService({
    this.apiClient = const ApiClient(),
  });

  final ApiClient apiClient;

  Future<List<Vehicle>> getVehicles() async {
    final response = await apiClient.get(
      '/vehicles',
    );

    if (response is! List) {
      throw const FormatException(
        'Araç listesi geçerli formatta alınamadı.',
      );
    }

    return response.map(
          (item) {
        if (item is! Map) {
          throw const FormatException(
            'Araç listesinde geçersiz veri bulundu.',
          );
        }

        return Vehicle.fromJson(
          Map<String, dynamic>.from(item),
        );
      },
    ).toList();
  }

  Future<Vehicle> getVehicleById(
      int vehicleId,
      ) async {
    final response = await apiClient.get(
      '/vehicles/$vehicleId',
    );

    if (response is! Map) {
      throw const FormatException(
        'Araç bilgisi geçerli formatta alınamadı.',
      );
    }

    return Vehicle.fromJson(
      Map<String, dynamic>.from(response),
    );
  }

  Future<Vehicle> createVehicle({
    required String plate,
    required String brand,
    required String model,
    required int modelYear,
    required int mileage,
  }) async {
    final response = await apiClient.post(
      '/vehicles',
      body: {
        'plate': plate.trim().toUpperCase(),
        'brand': brand.trim(),
        'model': model.trim(),
        'modelYear': modelYear,
        'mileage': mileage,
      },
    );

    if (response is! Map) {
      throw const FormatException(
        'Oluşturulan araç bilgisi alınamadı.',
      );
    }

    return Vehicle.fromJson(
      Map<String, dynamic>.from(response),
    );
  }

  Future<Vehicle> updateVehicle({
    required int vehicleId,
    required String plate,
    required String brand,
    required String model,
    required int modelYear,
    required int mileage,
  }) async {
    final response = await apiClient.put(
      '/vehicles/$vehicleId',
      body: {
        'plate': plate
            .trim()
            .toUpperCase()
            .replaceAll(
          RegExp(r'[^0-9A-Z]'),
          '',
        ),
        'brand': brand.trim(),
        'model': model.trim(),
        'modelYear': modelYear,
        'mileage': mileage,
      },
    );

    if (response is! Map) {
      throw const FormatException(
        'Güncellenen araç bilgisi alınamadı.',
      );
    }

    return Vehicle.fromJson(
      Map<String, dynamic>.from(response),
    );
  }

  Future<Vehicle> setPrimaryVehicle(
      int vehicleId,
      ) async {
    final response = await apiClient.put(
      '/vehicles/$vehicleId/primary',
      body: const {},
    );

    if (response is! Map) {
      throw const FormatException(
        'Ana araç bilgisi güncellenemedi.',
      );
    }

    return Vehicle.fromJson(
      Map<String, dynamic>.from(response),
    );
  }

  Future<void> deleteVehicle(
      int vehicleId,
      ) async {
    await apiClient.delete(
      '/vehicles/$vehicleId',
    );
  }
}