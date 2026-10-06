import '../models/wheat_transaction_model.dart';
import '../services/api_service.dart';

class WheatRepository {
  WheatRepository({ApiService? apiService}) : _api = apiService ?? ApiService.instance;

  final ApiService _api;


  // ============================================================
  // API
  // ============================================================

  /// GET /api/wheat
  Future<List<WheatTransactionModel>> getTransactionsFromApi() async {
    final response = await _api.get('/wheat');

    if (response is! List) {
      throw ApiException(
        message: 'Invalid response received from wheat transactions API.',
      );
    }

    return response
        .whereType<Map>()
        .map(
          (item) => WheatTransactionModel.fromJson(
            _fromApiJson(Map<String, dynamic>.from(item)),
          ),
        )
        .toList();
  }

  /// GET /api/wheat/:id
  Future<WheatTransactionModel> getTransactionFromApi(String id) async {
    final response = await _api.get('/wheat/$id');

    if (response is! Map) {
      throw ApiException(
        message: 'Invalid response received from wheat transaction API.',
      );
    }

    return WheatTransactionModel.fromJson(
      _fromApiJson(Map<String, dynamic>.from(response)),
    );
  }

  /// POST /api/wheat
  Future<WheatTransactionModel> createTransactionFromApi({
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
      '/wheat',
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
        message: 'Invalid response received while creating wheat transaction.',
      );
    }

    return WheatTransactionModel.fromJson(
      _fromApiJson(Map<String, dynamic>.from(response)),
    );
  }

  /// PUT /api/wheat/:id
  Future<WheatTransactionModel> updateTransactionFromApi({
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
      '/wheat/$id',
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
        message: 'Invalid response received while updating wheat transaction.',
      );
    }

    return WheatTransactionModel.fromJson(
      _fromApiJson(Map<String, dynamic>.from(response)),
    );
  }

  /// DELETE /api/wheat/:id
  Future<void> deleteTransactionFromApi(String id) async {
    await _api.delete('/wheat/$id');
  }
    /// Unified save: creates a new transaction if [transaction.id] is empty,
  /// otherwise updates the existing transaction.
  Future<WheatTransactionModel> save(WheatTransactionModel transaction) async {
    if (transaction.id.isEmpty) {
      return createTransactionFromApi(
        farmerId: transaction.farmerId,
        partyId: transaction.partyId,
        date: transaction.date,
        quantity: transaction.quantity,
        rate: transaction.rate,
        totalAmount: transaction.totalAmount,
        transactionType: transaction.transactionType,
        paidAmount: transaction.paidAmount,
        receivedAmount: transaction.receivedAmount,
        remainingAmount: transaction.remainingAmount,
        variety: transaction.variety,
        notes: transaction.notes,
      );
    }

    return updateTransactionFromApi(
      id: transaction.id,
      farmerId: transaction.farmerId,
      partyId: transaction.partyId,
      date: transaction.date,
      quantity: transaction.quantity,
      rate: transaction.rate,
      totalAmount: transaction.totalAmount,
      transactionType: transaction.transactionType,
      paidAmount: transaction.paidAmount,
      receivedAmount: transaction.receivedAmount,
      remainingAmount: transaction.remainingAmount,
      variety: transaction.variety,
      notes: transaction.notes,
    );
  }

  /// Unified delete wrapper.
  Future<void> delete(String id) async {
    await deleteTransactionFromApi(id);
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

      // Agar backend remaining_amount na bheje (null/missing) to null hi
      // rakhein, taake WheatTransactionModel.fromJson() isay khud
      // (total - paid / received) calculate kar le.
      'remainingAmount': json['remaining_amount'] == null
          ? null
          : _toDouble(json['remaining_amount']),

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
