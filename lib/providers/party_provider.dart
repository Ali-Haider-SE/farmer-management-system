import 'package:flutter/foundation.dart';

import '../models/khata_model.dart';
import '../models/party_model.dart';
import '../repositories/party_repository.dart';

class PartyProvider extends ChangeNotifier {
  PartyProvider({PartyRepository? repository})
    : _repository = repository ?? PartyRepository();

  final PartyRepository _repository;

  List<PartyModel> _models = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<Map<String, dynamic>> get parties =>
      _models.map((party) => party.toJson()).toList(growable: false);

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int get totalParties => _models.length;

  double get totalReceivable => _models.fold(
        0,
        (total, party) => total + (getPartyBalance(party.toJson()) > 0
            ? getPartyBalance(party.toJson())
            : 0),
      );

  double get totalPayable => _models.fold(
        0,
        (total, party) => total + (getPartyBalance(party.toJson()) < 0
            ? getPartyBalance(party.toJson()).abs()
            : 0),
      );

  double getPartyBalance(Map<String, dynamic> party) {
    var balance = _toDouble(party['openingBalance']);
    final openingType = party['openingBalanceType']?.toString();
    if (openingType == 'You Receive' || openingType == 'You Take') {
      balance = -balance;
    }

    final transactions = party['transactions'];
    if (transactions is List) {
      for (final raw in transactions.whereType<Map>()) {
        final item = Map<String, dynamic>.from(raw);
        final debit = _toDouble(item['debit']);
        final credit = _toDouble(item['credit']);
        if (debit != 0 || credit != 0) {
          balance += debit - credit;
        } else {
          final amount = _toDouble(item['amount']);
          balance += item['type']?.toString() == 'You Take' ? -amount : amount;
        }
      }
    }
    return balance;
  }

  Future<void> loadParties() async {
    _setLoading(true);
    _errorMessage = null;
    try {
      _models = await _repository.getParties();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> addParty({
    required String name,
    String phone = '',
    String address = '',
    double openingBalance = 0,
    String openingBalanceType = 'You Give',
  }) async {
    if (name.trim().isEmpty) {
      return _fail('Party name is required');
    }
    if (openingBalance < 0) {
      return _fail('Opening balance cannot be negative');
    }

    try {
      final saved = await _repository.create(
        PartyModel(
          id: '',
          name: name.trim(),
          phone: phone.trim(),
          address: address.trim(),
          openingBalance: openingBalance,
          openingBalanceType: openingBalanceType,
          createdAt: DateTime.now(),
        ),
      );
      _models = [..._models, saved];
      notifyListeners();
      return true;
    } catch (e) {
      return _fail('Failed to add party: $e');
    }
  }

  Future<bool> updateParty({
    required String partyId,
    required String name,
    String phone = '',
    String address = '',
    double openingBalance = 0,
    String openingBalanceType = 'You Give',
  }) async {
    if (partyId.trim().isEmpty) return _fail('Party ID is required');
    if (name.trim().isEmpty) return _fail('Party name is required');
    if (openingBalance < 0) {
      return _fail('Opening balance cannot be negative');
    }

    try {
      final existing = _models.where((p) => p.id == partyId).firstOrNull;
      if (existing == null) return _fail('Party not found');

      final saved = await _repository.update(
        existing.copyWith(
          name: name.trim(),
          phone: phone.trim(),
          address: address.trim(),
          openingBalance: openingBalance,
          openingBalanceType: openingBalanceType,
        ),
      );
      _replace(saved);
      notifyListeners();
      return true;
    } catch (e) {
      return _fail('Failed to update party: $e');
    }
  }

  Future<bool> deleteParty(String partyId) async {
    if (partyId.trim().isEmpty) return false;
    try {
      await _repository.delete(partyId);
      _models = _models.where((party) => party.id != partyId).toList();
      notifyListeners();
      return true;
    } catch (e) {
      return _fail('Failed to delete party: $e');
    }
  }

  Future<bool> addTransaction({
    required String partyId,
    required String type,
    required double amount,
    String note = '',
    DateTime? date,
  }) async {
    if (amount <= 0) return _fail('Amount must be greater than zero');
    if (type != 'You Give' && type != 'You Take') {
      return _fail('Invalid transaction type');
    }

    final party = _models.where((p) => p.id == partyId).firstOrNull;
    if (party == null) return _fail('Party not found');

    try {
      final tx = await _repository.addKhataTransaction(
        partyId: partyId,
        transaction: KhataModel(
          id: '',
          partyId: partyId,
          date: date ?? DateTime.now(),
          description: note.trim(),
          debit: type == 'You Give' ? amount : 0,
          credit: type == 'You Take' ? amount : 0,
        ),
      );
      _replace(party.copyWith(transactions: [...party.transactions, tx]));
      notifyListeners();
      return true;
    } catch (e) {
      return _fail('Failed to add transaction: $e');
    }
  }

  Future<bool> updateTransaction({
    required String partyId,
    required String transactionId,
    required String type,
    required double amount,
    String note = '',
  }) async {
    if (amount <= 0) return _fail('Amount must be greater than zero');
    if (type != 'You Give' && type != 'You Take') {
      return _fail('Invalid transaction type');
    }

    final party = _models.where((p) => p.id == partyId).firstOrNull;
    if (party == null) return _fail('Party not found');

    final existing = party.transactions.where((t) => t.id == transactionId).firstOrNull;
    if (existing == null) return _fail('Transaction not found');

    try {
      final tx = await _repository.updateKhataTransaction(
        partyId: partyId,
        transaction: existing.copyWith(
          description: note.trim(),
          debit: type == 'You Give' ? amount : 0,
          credit: type == 'You Take' ? amount : 0,
        ),
      );
      _replace(
        party.copyWith(
          transactions: party.transactions
              .map((item) => item.id == transactionId ? tx : item)
              .toList(),
        ),
      );
      notifyListeners();
      return true;
    } catch (e) {
      return _fail('Failed to update transaction: $e');
    }
  }

  Future<bool> deleteTransaction({
    required String partyId,
    required String transactionId,
  }) async {
    final party = _models.where((p) => p.id == partyId).firstOrNull;
    if (party == null) return _fail('Party not found');

    try {
      await _repository.deleteKhataTransaction(
        partyId: partyId,
        transactionId: transactionId,
      );
      _replace(
        party.copyWith(
          transactions: party.transactions
              .where((item) => item.id != transactionId)
              .toList(),
        ),
      );
      notifyListeners();
      return true;
    } catch (e) {
      return _fail('Failed to delete transaction: $e');
    }
  }

  Map<String, dynamic>? getPartyById(String partyId) {
    final party = _models.where((p) => p.id == partyId).firstOrNull;
    return party?.toJson();
  }

  List<Map<String, dynamic>> getPartyTransactions(String partyId) {
    final party = _models.where((p) => p.id == partyId).firstOrNull;
    return party?.transactions.map((item) => item.toJson()).toList() ?? [];
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void _replace(PartyModel saved) {
    _models = [
      for (final item in _models)
        if (item.id != saved.id) item,
      saved,
    ];
  }

  bool _fail(String message) {
    _errorMessage = message;
    notifyListeners();
    return false;
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}
