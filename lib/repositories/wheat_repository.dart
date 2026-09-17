import '../models/wheat_transaction_model.dart';
import '../services/storage_service.dart';

class WheatRepository {
  WheatRepository({StorageService? storageService})
    : _storage = storageService ?? StorageService.instance;

  final StorageService _storage;

  static const String _key = 'wheat_transactions';

  /// Raw transaction records used by the existing Wheat Management UI.
  /// Keeps the legacy map-based schema unchanged while exposing it through the repository.
  List<Map<String, dynamic>> getRawTransactions() {
    return _storage.getJsonList(_key);
  }

  Future<void> saveRawTransactions(List<Map<String, dynamic>> items) async {
    await _storage.setJsonList(_key, items);
  }

  List<WheatTransactionModel> getTransactions() {
    return _storage
        .getJsonList(_key)
        .map(WheatTransactionModel.fromJson)
        .toList();
  }

  List<WheatTransactionModel> getByFarmer(String farmerId) {
    return getTransactions()
        .where((item) => item.farmerId == farmerId)
        .toList();
  }

  List<WheatTransactionModel> getByParty(String partyId) {
    return getTransactions().where((item) => item.partyId == partyId).toList();
  }

  WheatTransactionModel? getById(String id) {
    for (final item in getTransactions()) {
      if (item.id == id) return item;
    }
    return null;
  }

  Future<void> save(WheatTransactionModel transaction) async {
    final items = getTransactions();

    final index = items.indexWhere((item) => item.id == transaction.id);

    if (index >= 0) {
      items[index] = transaction;
    } else {
      items.add(transaction);
    }

    await _save(items);
  }

  Future<void> delete(String id) async {
    final items = getTransactions().where((item) => item.id != id).toList();

    await _save(items);
  }

  Future<void> _save(List<WheatTransactionModel> items) async {
    await _storage.setJsonList(
      _key,
      items.map((item) => item.toJson()).toList(),
    );
  }

  Future<void> clear() async {
    await _storage.remove(_key);
  }
}
