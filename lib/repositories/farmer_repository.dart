import '../models/farmer_model.dart';
import '../services/api_service.dart';

class FarmerRepository {
  final ApiService _apiService = ApiService.instance;

  Future<List<FarmerModel>> getFarmers() async {
    final response = await _apiService.get('/farmers');

    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to load farmers');
    }

    final farmers = response['farmers'] as List<dynamic>? ?? [];

    return farmers
        .map(
          (item) =>
              FarmerModel.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
  }

  Future<FarmerModel> getFarmer(String id) async {
    final response = await _apiService.get('/farmers/$id');

    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Farmer not found');
    }

    return FarmerModel.fromJson(
      Map<String, dynamic>.from(response['farmer'] as Map),
    );
  }

  Future<FarmerModel> createFarmer(FarmerModel farmer) async {
    final response = await _apiService.post('/farmers', body: farmer.toJson());

    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to create farmer');
    }

    return FarmerModel.fromJson(
      Map<String, dynamic>.from(response['farmer'] as Map),
    );
  }

  Future<FarmerModel> updateFarmer(FarmerModel farmer) async {
    final response = await _apiService.put(
      '/farmers/${farmer.id}',
      body: farmer.toJson(),
    );

    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to update farmer');
    }

    return FarmerModel.fromJson(
      Map<String, dynamic>.from(response['farmer'] as Map),
    );
  }

  Future<void> deleteFarmer(String id) async {
    final response = await _apiService.delete('/farmers/$id');

    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to delete farmer');
    }
  }
}
