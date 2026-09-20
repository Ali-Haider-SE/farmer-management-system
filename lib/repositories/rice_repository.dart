import '../models/rice_transaction_model.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';

class RiceRepository {
  RiceRepository({StorageService? storageService, ApiService? apiService})
    : _storage = storageService ?? StorageService.instance,
      _api = apiService ?? ApiService.instance;

  final StorageService _storage;
  final ApiService _api;

  static const String _key = 'rice_transactions';

  // ============================================================
  // LOCAL STORAGE
  // ============================================================

  List<Map<String, dynamic>> getRawTransactions() {
    return _storage.getJsonList(_key);
  }

  Future<void> saveRawTransactions(List<Map<String, dynamic>> items) async {
    await _storage.setJsonList(_key, items);
  }

  List<RiceTransactionModel> getTransactions() {
    return _storage
        .getJsonList(_key)
        .map(RiceTransactionModel.fromJson)
        .toList();
  }

  List<RiceTransactionModel> getByFarmer(String farmerId) {
    return getTransactions()
        .where((item) => item.farmerId == farmerId)
        .toList();
  }

  List<RiceTransactionModel> getByParty(String partyId) {
    return getTransactions().where((item) => item.partyId == partyId).toList();
  }

  RiceTransactionModel? getById(String id) {
    for (final item in getTransactions()) {
      if (item.id == id) {
        return item;
      }
    }

    return null;
  }

  Future<void> save(RiceTransactionModel transaction) async {
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

  Future<void> _save(List<RiceTransactionModel> items) async {
    await _storage.setJsonList(
      _key,
      items.map((item) => item.toJson()).toList(),
    );
  }

  Future<void> clear() async {
    await _storage.remove(_key);
  }

  // ============================================================
  // API
  // ============================================================

  /// GET /api/rice
  Future<List<RiceTransactionModel>> getTransactionsFromApi() async {
    final response = await _api.get('/rice');

    if (response is! List) {
      throw ApiException(
        message: 'Invalid response received from rice transactions API.',
      );
    }

    return response
        .whereType<Map>()
        .map(
          (item) => RiceTransactionModel.fromJson(
            _fromApiJson(Map<String, dynamic>.from(item)),
          ),
        )
        .toList();
  }

  /// GET /api/rice/:id
  Future<RiceTransactionModel> getTransactionFromApi(String id) async {
    final response = await _api.get('/rice/$id');

    if (response is! Map) {
      throw ApiException(
        message: 'Invalid response received from rice transaction API.',
      );
    }

    return RiceTransactionModel.fromJson(
      _fromApiJson(Map<String, dynamic>.from(response)),
    );
  }

  /// POST /api/rice
  Future<RiceTransactionModel> createTransactionFromApi({
    String? farmerId,
    String? partyId,
    required DateTime date,
    required double quantity,
    required double rate,
    required double totalAmount,
    required String transactionType,
    double paidAmount = 0,
    double receivedAmount = 0,
    double remainingAmount = 0,
    String? variety,
    String? notes,
  }) async {
    final response = await _api.post(
      '/rice',
      body: _toApiJson(
        farmerId: farmerId,
        partyId: partyId,
        date: date,
        quantity: quantity,
        rate: rate,
        totalAmount: totalAmount,
        transactionType: transactionType,
        paidAmount: paidAmount,
        receivedAmount: receivedAmount,
        remainingAmount: remainingAmount,
        variety: variety,
        notes: notes,
      ),
    );

    if (response is! Map) {
      throw ApiException(
        message: 'Invalid response received while creating rice transaction.',
      );
    }

    return RiceTransactionModel.fromJson(
      _fromApiJson(Map<String, dynamic>.from(response)),
    );
  }

  /// PUT /api/rice/:id
  Future<RiceTransactionModel> updateTransactionFromApi({
    required String id,
    String? farmerId,
    String? partyId,
    required DateTime date,
    required double quantity,
    required double rate,
    required double totalAmount,
    required String transactionType,
    double paidAmount = 0,
    double receivedAmount = 0,
    double remainingAmount = 0,
    String? variety,
    String? notes,
  }) async {
    final response = await _api.put(
      '/rice/$id',
      body: _toApiJson(
        farmerId: farmerId,
        partyId: partyId,
        date: date,
        quantity: quantity,
        rate: rate,
        totalAmount: totalAmount,
        transactionType: transactionType,
        paidAmount: paidAmount,
        receivedAmount: receivedAmount,
        remainingAmount: remainingAmount,
        variety: variety,
        notes: notes,
      ),
    );

    if (response is! Map) {
      throw ApiException(
        message: 'Invalid response received while updating rice transaction.',
      );
    }

    return RiceTransactionModel.fromJson(
      _fromApiJson(Map<String, dynamic>.from(response)),
    );
  }

  /// DELETE /api/rice/:id
  Future<void> deleteTransactionFromApi(String id) async {
    await _api.delete('/rice/$id');
  }

  // ============================================================
  // API JSON MAPPING
  // ============================================================

  /// Flutter model -> Backend API
  ///
  /// Flutter:
  /// farmerId
  /// partyId
  /// totalAmount
  /// transactionType
  ///
  /// Backend:
  /// farmer_id
  /// party_id
  /// total_amount
  /// transaction_type

  Map<String, dynamic> _toApiJson({
    String? farmerId,
    String? partyId,
    required DateTime date,
    required double quantity,
    required double rate,
    required double totalAmount,
    required String transactionType,
    required double paidAmount,
    required double receivedAmount,
    required double remainingAmount,
    String? variety,
    String? notes,
  }) {
    return {
      'farmer_id': _nullableString(farmerId),
      'party_id': _nullableString(partyId),
      'date': date.toIso8601String(),
      'quantity': quantity,
      'rate': rate,
      'total_amount': totalAmount,
      'transaction_type': _apiTransactionType(transactionType),
      'paid_amount': paidAmount,
      'received_amount': receivedAmount,
      'remaining_amount': remainingAmount,
      'variety': variety,
      'notes': notes,
    };
  }

  /// Backend API -> Flutter model
  Map<String, dynamic> _fromApiJson(Map<String, dynamic> json) {
    return {
      'id': json['id']?.toString() ?? '',
      'farmerId': json['farmer_id']?.toString() ?? '',
      'partyId': json['party_id']?.toString() ?? '',
      'date': json['date']?.toString() ?? '',
      'quantity': _toDouble(json['quantity']),
      'rate': _toDouble(json['rate']),
      'totalAmount': _toDouble(json['total_amount']),
      'transactionType': _displayTransactionType(
        json['transaction_type']?.toString(),
      ),
      'paidAmount': _toDouble(json['paid_amount']),
      'receivedAmount': _toDouble(json['received_amount']),
      'remainingAmount': _toDouble(json['remaining_amount']),
      'variety': json['variety'],
      'notes': json['notes'],
    };
  }

  // ============================================================
  // HELPERS
  // ============================================================

  String _apiTransactionType(String value) {
    final normalized = value.trim().toLowerCase();

    if (normalized == 'sale') {
      return 'sale';
    }

    return 'purchase';
  }

  String _displayTransactionType(String? value) {
    if (value?.trim().toLowerCase() == 'sale') {
      return 'Sale';
    }

    return 'Purchase';
  }

  String? _nullableString(String? value) {
    if (value == null) {
      return null;
    }

    final trimmed = value.trim();

    if (trimmed.isEmpty) {
      return null;
    }

    return trimmed;
  }

  double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}
