import '../models/stock_model.dart';
import '../services/api_service.dart';

class StockRepository {
  StockRepository({ApiService? apiService})
    : _api = apiService ?? ApiService.instance;

  final ApiService _api;

  Future<List<StockModel>> getStockFromApi() async {
    final response = await _api.get('/stock');

    if (response is! Map || response['stock'] is! List) {
      throw const ApiException(
        message: 'Invalid stock response from server.',
        type: ApiExceptionType.unknown,
      );
    }

    return (response['stock'] as List)
        .whereType<Map>()
        .map((item) => StockModel.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<StockModel> getByIdFromApi(String id) async {
    final response = await _api.get('/stock/$id');

    if (response is! Map || response['stock'] is! Map) {
      throw const ApiException(
        message: 'Invalid stock record from server.',
        type: ApiExceptionType.unknown,
      );
    }

    return StockModel.fromJson(
      Map<String, dynamic>.from(response['stock'] as Map),
    );
  }

  Future<StockModel> createFromApi({
    required String productName,
    String? productType,
    required double quantity,
    String unit = 'kg',
    required double averageRate,
    String? warehouse,
    bool isActive = true,
    String movementType = 'IN',
    DateTime? date,
    double? rate,
    String? source,
    String? reference,
    String? notes,
  }) async {
    final response = await _api.post(
      '/stock',
      body: {
        'productName': productName,
        'productType': productType,
        'quantity': quantity,
        'unit': unit,
        'averageRate': averageRate,
        'warehouse': warehouse,
        'isActive': isActive,
        'movementType': movementType,
        'date': date?.toIso8601String(),
        'rate': rate,
        'source': source,
        'reference': reference,
        'notes': notes,
      },
    );

    if (response is! Map || response['stock'] is! Map) {
      throw const ApiException(
        message: 'Invalid create stock response from server.',
        type: ApiExceptionType.unknown,
      );
    }

    return StockModel.fromJson(
      Map<String, dynamic>.from(response['stock'] as Map),
    );
  }

  Future<StockModel> updateFromApi(StockModel stock) async {
    final response = await _api.put(
      '/stock/${stock.id}',
      body: {
        'productName': stock.productName,
        'productType': stock.productType,
        'quantity': stock.quantity,
        'unit': stock.unit,
        'averageRate': stock.averageRate,
        'warehouse': stock.warehouse,
        'isActive': stock.isActive,
      },
    );

    if (response is! Map || response['stock'] is! Map) {
      throw const ApiException(
        message: 'Invalid update stock response from server.',
        type: ApiExceptionType.unknown,
      );
    }

    return StockModel.fromJson(
      Map<String, dynamic>.from(response['stock'] as Map),
    );
  }

  Future<StockModel> recordMovement({
    required String stockId,
    required String movementType,
    required double quantity,
    double? rate,
    DateTime? date,
    String? source,
    String? reference,
    String? notes,
  }) async {
    final response = await _api.post(
      '/stock',
      body: {
        'stockId': stockId,
        'movementType': movementType,
        'quantity': quantity,
        'rate': rate,
        'date': date?.toIso8601String(),
        'source': source,
        'reference': reference,
        'notes': notes,
      },
    );

    if (response is! Map || response['stock'] is! Map) {
      throw const ApiException(
        message: 'Invalid stock movement response from server.',
        type: ApiExceptionType.unknown,
      );
    }

    return StockModel.fromJson(
      Map<String, dynamic>.from(response['stock'] as Map),
    );
  }

  Future<void> delete(String id) async {
    await _api.delete('/stock/$id');
  }
}
