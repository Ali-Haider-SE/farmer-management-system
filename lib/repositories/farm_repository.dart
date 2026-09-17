import '../models/farm_model.dart';
import '../services/api_service.dart';

class FarmRepository {
  FarmRepository({ApiService? apiService})
    : _apiService = apiService ?? ApiService.instance;

  final ApiService _apiService;

  Future<List<FarmModel>> getFarms() async {
    final response = await _apiService.get('/farms');

    final data = response is Map<String, dynamic>
        ? response['farms'] ?? response['data']
        : null;

    if (data is! List) {
      return [];
    }

    return data
        .whereType<Map>()
        .map((item) => FarmModel.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<FarmModel> getFarm(String id) async {
    final response = await _apiService.get('/farms/$id');

    final data = response is Map<String, dynamic>
        ? response['farm'] ?? response['data']
        : null;

    if (data is! Map) {
      throw Exception('Invalid farm response');
    }

    return FarmModel.fromJson(Map<String, dynamic>.from(data));
  }

  Future<FarmModel> addFarm(FarmModel farm) async {
    final response = await _apiService.post(
      '/farms',
      body: farm.toJson()..remove('id'),
    );

    final data = response is Map<String, dynamic>
        ? response['farm'] ?? response['data']
        : null;

    if (data is! Map) {
      throw Exception('Invalid farm response');
    }

    return FarmModel.fromJson(Map<String, dynamic>.from(data));
  }

  Future<FarmModel> updateFarm(FarmModel farm) async {
    final response = await _apiService.put(
      '/farms/${farm.id}',
      body: farm.toJson(),
    );

    final data = response is Map<String, dynamic>
        ? response['farm'] ?? response['data']
        : null;

    if (data is! Map) {
      throw Exception('Invalid farm response');
    }

    return FarmModel.fromJson(Map<String, dynamic>.from(data));
  }

  Future<void> deleteFarm(String id) async {
    await _apiService.delete('/farms/$id');
  }

  Future<List<Map<String, dynamic>>> getFarmRecords() async {
    final farms = await getFarms();

    return farms.map((farm) {
      return {
        'id': farm.id,
        'farmerId': farm.farmerId,
        'name': farm.farmName,
        'farmName': farm.farmName,
        'farmer': farm.farmerId,
        'location': farm.location,
        'area': farm.area,
        'areaUnit': farm.areaUnit,
        'crop': farm.cropType ?? '',
        'cropType': farm.cropType ?? '',
        'isActive': farm.isActive,
      };
    }).toList();
  }

  Future<void> saveFarmRecords(List<Map<String, dynamic>> records) async {
    for (final record in records) {
      final farm = FarmModel(
        id: record['id']?.toString() ?? '',
        farmerId:
            record['farmerId']?.toString() ??
            record['farmer']?.toString() ??
            '',
        farmName:
            record['farmName']?.toString() ?? record['name']?.toString() ?? '',
        location: record['location']?.toString() ?? '',
        area: double.tryParse(record['area']?.toString() ?? '') ?? 0,
        areaUnit: record['areaUnit']?.toString() ?? 'Acre',
        cropType: record['cropType']?.toString() ?? record['crop']?.toString(),
        isActive: record['isActive'] as bool? ?? true,
      );

      if (farm.id.isEmpty) {
        await addFarm(farm);
      } else {
        await updateFarm(farm);
      }
    }
  }
}
