import '../models/khata_model.dart';
import '../models/party_model.dart';
import '../services/api_service.dart';

class PartyRepository {
  PartyRepository({ApiService? apiService})
    : _api = apiService ?? ApiService.instance;

  final ApiService _api;

  // =====================================================
  // GET PARTIES
  // =====================================================

  Future<List<PartyModel>> getParties() async {
    final response = await _api.get('/parties');

    if (response is Map && response['parties'] is List) {
      return (response['parties'] as List)
          .whereType<Map>()
          .map((item) => PartyModel.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    }

    if (response is List) {
      return response
          .whereType<Map>()
          .map((item) => PartyModel.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    }

    return [];
  }

  // =====================================================
  // ACTIVE PARTIES
  // =====================================================

  Future<List<PartyModel>> getActiveParties() async {
    final parties = await getParties();

    return parties.where((party) => party.isActive).toList();
  }

  // =====================================================
  // GET BY ID
  // =====================================================

  Future<PartyModel?> getById(String id) async {
    final parties = await getParties();

    for (final party in parties) {
      if (party.id == id) {
        return party;
      }
    }

    return null;
  }

  // =====================================================
  // SEARCH
  // =====================================================

  Future<List<PartyModel>> search(String query) async {
    final parties = await getParties();

    final value = query.trim().toLowerCase();

    if (value.isEmpty) {
      return parties;
    }

    return parties.where((party) {
      return party.name.toLowerCase().contains(value) ||
          party.phone.toLowerCase().contains(value) ||
          party.address.toLowerCase().contains(value);
    }).toList();
  }

  // =====================================================
  // SAVE PARTY
  // =====================================================

  Future<void> save(PartyModel party) async {
    final body = {
      'name': party.name,
      'phone': party.phone,
      'address': party.address,
      'partyType': party.partyType,
      'openingBalance': party.openingBalance,
      'openingBalanceType': party.openingBalanceType,
      'isActive': party.isActive,
      'createdAt': party.createdAt.toIso8601String(),
    };

    final existing = await getById(party.id);

    if (existing == null) {
      await _api.post('/parties', body: body);
    } else {
      await _api.put('/parties/${party.id}', body: body);
    }
  }

  // =====================================================
  // DELETE
  // =====================================================

  Future<void> delete(String id) async {
    await _api.delete('/parties/$id');
  }

  // =====================================================
  // SAVE ALL
  // =====================================================

  Future<void> saveAll(List<PartyModel> parties) async {
    for (final party in parties) {
      await save(party);
    }
  }

  // =====================================================
  // CROP TRANSACTION → PARTY KHATA SYNC
  // =====================================================

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
    if (partyId == null || partyId.trim().isEmpty) {
      return;
    }

    final reference = '${crop.toUpperCase()}:$transactionId';

    if (remainingAmount <= 0) {
      await removeCropTransactionKhata(
        transactionId: transactionId,
        crop: crop,
      );
      return;
    }

    final isPurchase = type.trim().toLowerCase() == 'purchase';

    String description;

    if (quantity != null && rate != null) {
      description =
          '$crop ${isPurchase ? 'Purchase' : 'Sale'}'
          ' - ${quantity.toStringAsFixed(2)} Maund'
          ' @ Rs. ${rate.toStringAsFixed(0)}';
    } else {
      description = '$crop ${isPurchase ? 'Purchase' : 'Sale'}';
    }

    await _api.post(
      '/parties/$partyId/transactions/sync',
      body: {
        'transactionId': transactionId,
        'reference': reference,
        'date': date.toIso8601String(),
        'description': description,
        'debit': isPurchase ? 0 : remainingAmount,
        'credit': isPurchase ? remainingAmount : 0,
        'balance': 0,
      },
    );
  }

  // =====================================================
  // REMOVE CROP TRANSACTION
  // =====================================================

  Future<void> removeCropTransactionKhata({
    required String transactionId,
    required String crop,
  }) async {
    final reference = '${crop.toUpperCase()}:$transactionId';

    await _api.delete(
      '/parties/transactions/reference/${Uri.encodeComponent(reference)}',
    );
  }

  // =====================================================
  // ADD KHATA TRANSACTION
  // =====================================================

  Future<void> addKhataTransaction({
    required String partyId,
    required KhataModel transaction,
  }) async {
    await _api.post(
      '/parties/$partyId/transactions',
      body: {
        'id': transaction.id,
        'partyId': partyId,
        'date': transaction.date.toIso8601String(),
        'description': transaction.description,
        'debit': transaction.debit,
        'credit': transaction.credit,
        'balance': transaction.balance,
        'reference': transaction.reference,
      },
    );
  }

  // =====================================================
  // UPDATE KHATA TRANSACTION
  // =====================================================

  Future<void> updateKhataTransaction({
    required String partyId,
    required KhataModel transaction,
  }) async {
    await _api.put(
      '/parties/$partyId/transactions/${transaction.id}',
      body: {
        'date': transaction.date.toIso8601String(),
        'description': transaction.description,
        'debit': transaction.debit,
        'credit': transaction.credit,
        'balance': transaction.balance,
        'reference': transaction.reference,
      },
    );
  }

  // =====================================================
  // DELETE KHATA TRANSACTION
  // =====================================================

  Future<void> deleteKhataTransaction({
    required String partyId,
    required String transactionId,
  }) async {
    await _api.delete('/parties/$partyId/transactions/$transactionId');
  }
}
