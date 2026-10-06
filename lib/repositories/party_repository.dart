import '../models/khata_model.dart';
import '../models/party_model.dart';
import '../services/api_service.dart';

class PartyRepository {
  PartyRepository({ApiService? apiService}) : _api = apiService ?? ApiService.instance;

  final ApiService _api;

  Future<List<PartyModel>> getParties() async {
    final response = await _api.get('/parties');

    if (response is Map && response['parties'] is List) {
      return (response['parties'] as List)
          .whereType<Map>()
          .map((item) => PartyModel.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    }

    throw const ApiException(
      message: 'Invalid parties response from server.',
      type: ApiExceptionType.unknown,
    );
  }

  Future<List<PartyModel>> getActiveParties() async {
    final parties = await getParties();
    return parties.where((party) => party.isActive).toList();
  }

  Future<PartyModel?> getById(String id) async {
    final response = await _api.get('/parties/$id');

    if (response is! Map || response['party'] is! Map) {
      return null;
    }

    return PartyModel.fromJson(
      Map<String, dynamic>.from(response['party'] as Map),
    );
  }

  Future<List<PartyModel>> search(String query) async {
    final parties = await getParties();
    final value = query.trim().toLowerCase();
    if (value.isEmpty) return parties;

    return parties.where((party) {
      return party.name.toLowerCase().contains(value) ||
          party.phone.toLowerCase().contains(value) ||
          party.address.toLowerCase().contains(value);
    }).toList();
  }

  Future<PartyModel> create(PartyModel party) async {
    final response = await _api.post(
      '/parties',
      body: _partyBody(party),
    );

    if (response is! Map || response['party'] is! Map) {
      throw const ApiException(
        message: 'Invalid create party response from server.',
        type: ApiExceptionType.unknown,
      );
    }

    return PartyModel.fromJson(
      Map<String, dynamic>.from(response['party'] as Map),
    );
  }

  Future<PartyModel> update(PartyModel party) async {
    final response = await _api.put(
      '/parties/${party.id}',
      body: _partyBody(party),
    );

    if (response is! Map || response['party'] is! Map) {
      throw const ApiException(
        message: 'Invalid update party response from server.',
        type: ApiExceptionType.unknown,
      );
    }

    return PartyModel.fromJson(
      Map<String, dynamic>.from(response['party'] as Map),
    );
  }

  Future<void> delete(String id) async {
    await _api.delete('/parties/$id');
  }
  /// Unified save: creates a new party if [party.id] is empty,
  /// otherwise updates the existing party.
  Future<PartyModel> save(PartyModel party) async {
    if (party.id.isEmpty) {
      return create(party);
    }

    return update(party);
  }
  Future<KhataModel> addKhataTransaction({
    required String partyId,
    required KhataModel transaction,
  }) async {
    final response = await _api.post(
      '/khata',
      body: {
        'id': transaction.id,
        'partyId': partyId,
        'date': transaction.date.toIso8601String(),
        'description': transaction.description,
        'debit': transaction.debit,
        'credit': transaction.credit,
        'reference': transaction.reference,
      },
    );

    if (response is! Map || response['transaction'] is! Map) {
      throw const ApiException(
        message: 'Invalid Khata transaction response from server.',
        type: ApiExceptionType.unknown,
      );
    }

    return KhataModel.fromJson(
      Map<String, dynamic>.from(response['transaction'] as Map),
    );
  }

  Future<KhataModel> updateKhataTransaction({
    required String partyId,
    required KhataModel transaction,
  }) async {
    final response = await _api.put(
      '/khata/${transaction.id}',
      body: {
        'partyId': partyId,
        'date': transaction.date.toIso8601String(),
        'description': transaction.description,
        'debit': transaction.debit,
        'credit': transaction.credit,
        'reference': transaction.reference,
      },
    );

    if (response is! Map || response['transaction'] is! Map) {
      throw const ApiException(
        message: 'Invalid updated Khata transaction response from server.',
        type: ApiExceptionType.unknown,
      );
    }

    return KhataModel.fromJson(
      Map<String, dynamic>.from(response['transaction'] as Map),
    );
  }

  Future<void> deleteKhataTransaction({
    required String partyId,
    required String transactionId,
  }) async {
    await _api.delete('/khata/$transactionId');
  }

  Future<void> syncCropTransaction({
    required String? partyId,
    required String transactionId,
    required String crop,
    required String type,
    required DateTime date,
    required double totalAmount,
    required double remainingAmount,
    double? quantity,
    double? rate,
  }) async {
    if (partyId == null || partyId.trim().isEmpty || remainingAmount <= 0) {
      if (partyId != null && partyId.trim().isNotEmpty) {
        await removeCropTransactionKhata(
          transactionId: transactionId,
          crop: crop,
        );
      }
      return;
    }

    final isPurchase = type.trim().toLowerCase() == 'purchase';
    final reference = '${crop.toUpperCase()}:$transactionId';
    final description = quantity != null && rate != null
        ? '$crop ${isPurchase ? 'Purchase' : 'Sale'} - ${quantity.toStringAsFixed(2)} Maund @ Rs. ${rate.toStringAsFixed(0)}'
        : '$crop ${isPurchase ? 'Purchase' : 'Sale'}';

    await _api.post(
      '/khata',
      body: {
        'partyId': partyId,
        'date': date.toIso8601String(),
        'description': description,
        'debit': isPurchase ? 0 : remainingAmount,
        'credit': isPurchase ? remainingAmount : 0,
        'reference': reference,
      },
    );
  }

  Future<void> removeCropTransactionKhata({
    required String transactionId,
    required String crop,
  }) async {
    final reference = '${crop.toUpperCase()}:$transactionId';
    await _api.delete('/khata/reference/${Uri.encodeComponent(reference)}');
  }

  Map<String, dynamic> _partyBody(PartyModel party) {
    return {
      'name': party.name,
      'phone': party.phone,
      'address': party.address,
      'partyType': party.partyType,
      'openingBalance': party.openingBalance,
      'openingBalanceType': party.openingBalanceType,
      'isActive': party.isActive,
      'createdAt': party.createdAt.toIso8601String(),
    };
  }
}
