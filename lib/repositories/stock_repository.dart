import '../models/stock_model.dart';
import '../services/storage_service.dart';

class StockRepository {
  StockRepository({StorageService? storageService})
    : _storage = storageService ?? StorageService.instance;

  final StorageService _storage;

  static const String _key = 'stock';
  static const String movementsKey = 'stock_movements';

  /// Legacy map-based stock movements used by Stock Management.
  List<Map<String, dynamic>> getRawMovements() {
    return _storage.getJsonList(movementsKey);
  }

  Future<void> saveRawMovements(List<Map<String, dynamic>> items) async {
    await _storage.setJsonList(movementsKey, items);
  }

  List<StockModel> getStock() {
    return _storage.getJsonList(_key).map(StockModel.fromJson).toList();
  }

  List<StockModel> getActiveStock() {
    return getStock().where((item) => item.isActive).toList();
  }

  StockModel? getById(String id) {
    for (final item in getStock()) {
      if (item.id == id) return item;
    }
    return null;
  }

  List<StockModel> search(String query) {
    final value = query.trim().toLowerCase();

    if (value.isEmpty) return getStock();

    return getStock().where((item) {
      return item.productName.toLowerCase().contains(value) ||
          item.productType.toLowerCase().contains(value);
    }).toList();
  }

  Future<void> save(StockModel stock) async {
    final items = getStock();

    final index = items.indexWhere((item) => item.id == stock.id);

    if (index >= 0) {
      items[index] = stock;
    } else {
      items.add(stock);
    }

    await _save(items);
  }

  Future<void> delete(String id) async {
    final items = getStock().where((item) => item.id != id).toList();

    await _save(items);
  }

  Future<void> _save(List<StockModel> items) async {
    await _storage.setJsonList(
      _key,
      items.map((item) => item.toJson()).toList(),
    );
  }

  Future<void> clear() async {
    await _storage.remove(_key);
  }
}
