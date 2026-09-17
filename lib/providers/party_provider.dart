import 'package:flutter/foundation.dart';
import '../models/party_model.dart';

import '../repositories/party_repository.dart';

class PartyProvider extends ChangeNotifier {
  // =====================================================
  // REPOSITORY
  // =====================================================

  final PartyRepository _repository = PartyRepository();

  // =====================================================
  // STATE
  // =====================================================

  List<Map<String, dynamic>> _parties = [];

  bool _isLoading = false;

  String? _errorMessage;

  // =====================================================
  // GETTERS
  // =====================================================

  List<Map<String, dynamic>> get parties => List.unmodifiable(_parties);

  bool get isLoading => _isLoading;

  String? get errorMessage => _errorMessage;

  int get totalParties => _parties.length;

  // =====================================================
  // TOTAL RECEIVABLE
  // =====================================================

  double get totalReceivable {
    double total = 0;

    for (final party in _parties) {
      final balance = getPartyBalance(party);

      if (balance > 0) {
        total += balance;
      }
    }

    return total;
  }

  // =====================================================
  // TOTAL PAYABLE
  // =====================================================

  double get totalPayable {
    double total = 0;

    for (final party in _parties) {
      final balance = getPartyBalance(party);

      if (balance < 0) {
        total += balance.abs();
      }
    }

    return total;
  }

  // =====================================================
  // PARTY BALANCE
  // =====================================================

  double getPartyBalance(Map<String, dynamic> party) {
    double balance = 0;

    // ---------------------------------------------------
    // OPENING BALANCE
    // ---------------------------------------------------

    final openingBalance = _toDouble(party['openingBalance']);

    final openingBalanceType = party['openingBalanceType']?.toString();

    if (openingBalanceType == 'You Give') {
      balance += openingBalance;
    } else if (openingBalanceType == 'You Take') {
      balance -= openingBalance;
    }

    // ---------------------------------------------------
    // TRANSACTIONS
    // ---------------------------------------------------

    final transactions = party['transactions'];

    if (transactions is List) {
      for (final item in transactions) {
        if (item is! Map) {
          continue;
        }

        final transaction = Map<String, dynamic>.from(item);

        final amount = _toDouble(transaction['amount']);

        final type = transaction['type']?.toString();

        if (type == 'You Give') {
          balance += amount;
        } else if (type == 'You Take') {
          balance -= amount;
        }
      }
    }

    return balance;
  }

  // =====================================================
  // LOAD PARTIES
  // =====================================================

  Future<void> loadParties() async {
    _setLoading(true);

    try {
      _errorMessage = null;

      final records = await _repository.getParties();

      _parties = records.map((party) => party.toJson()).toList();

      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to load parties: $e';

      debugPrint('PartyProvider loadParties error: $e');
    } finally {
      _setLoading(false);
    }
  }

  // =====================================================
  // ADD PARTY
  // =====================================================

  Future<bool> addParty({
    required String name,
    String phone = '',
    String address = '',
    double openingBalance = 0,
    String openingBalanceType = 'You Give',
  }) async {
    if (name.trim().isEmpty) {
      _errorMessage = 'Party name is required';

      notifyListeners();

      return false;
    }

    if (openingBalance < 0) {
      _errorMessage = 'Opening balance cannot be negative';

      notifyListeners();

      return false;
    }

    try {
      _errorMessage = null;

      final now = DateTime.now();

      final party = <String, dynamic>{
        'id': now.microsecondsSinceEpoch.toString(),
        'name': name.trim(),
        'phone': phone.trim(),
        'address': address.trim(),
        'openingBalance': openingBalance,
        'openingBalanceType': openingBalanceType,
        'createdAt': now.toIso8601String(),
        'transactions': <Map<String, dynamic>>[],
      };

      _parties.add(party);

      await _save();

      notifyListeners();

      return true;
    } catch (e) {
      _errorMessage = 'Failed to add party: $e';

      debugPrint('PartyProvider addParty error: $e');

      notifyListeners();

      return false;
    }
  }

  // =====================================================
  // UPDATE PARTY
  // =====================================================

  Future<bool> updateParty({
    required String partyId,
    required String name,
    String phone = '',
    String address = '',
    double openingBalance = 0,
    String openingBalanceType = 'You Give',
  }) async {
    if (partyId.trim().isEmpty) {
      _errorMessage = 'Party ID is required';

      notifyListeners();

      return false;
    }

    if (name.trim().isEmpty) {
      _errorMessage = 'Party name is required';

      notifyListeners();

      return false;
    }

    if (openingBalance < 0) {
      _errorMessage = 'Opening balance cannot be negative';

      notifyListeners();

      return false;
    }

    try {
      _errorMessage = null;

      final index = _parties.indexWhere(
        (party) => party['id']?.toString() == partyId,
      );

      if (index == -1) {
        _errorMessage = 'Party not found';

        notifyListeners();

        return false;
      }

      final party = _parties[index];

      party['name'] = name.trim();
      party['phone'] = phone.trim();
      party['address'] = address.trim();
      party['openingBalance'] = openingBalance;
      party['openingBalanceType'] = openingBalanceType;

      await _save();

      notifyListeners();

      return true;
    } catch (e) {
      _errorMessage = 'Failed to update party: $e';

      debugPrint('PartyProvider updateParty error: $e');

      notifyListeners();

      return false;
    }
  }

  // =====================================================
  // DELETE PARTY
  // =====================================================

  Future<bool> deleteParty(String partyId) async {
    if (partyId.trim().isEmpty) {
      return false;
    }

    try {
      _errorMessage = null;

      final index = _parties.indexWhere(
        (party) => party['id']?.toString() == partyId,
      );

      if (index == -1) {
        _errorMessage = 'Party not found';

        notifyListeners();

        return false;
      }

      _parties.removeAt(index);

      await _save();

      notifyListeners();

      return true;
    } catch (e) {
      _errorMessage = 'Failed to delete party: $e';

      debugPrint('PartyProvider deleteParty error: $e');

      notifyListeners();

      return false;
    }
  }

  // =====================================================
  // ADD TRANSACTION
  // =====================================================

  Future<bool> addTransaction({
    required String partyId,
    required String type,
    required double amount,
    String note = '',
    DateTime? date,
  }) async {
    if (partyId.trim().isEmpty) {
      _errorMessage = 'Party is required';

      notifyListeners();

      return false;
    }

    if (amount <= 0) {
      _errorMessage = 'Amount must be greater than zero';

      notifyListeners();

      return false;
    }

    if (type != 'You Give' && type != 'You Take') {
      _errorMessage = 'Invalid transaction type';

      notifyListeners();

      return false;
    }

    try {
      _errorMessage = null;

      final partyIndex = _parties.indexWhere(
        (party) => party['id']?.toString() == partyId,
      );

      if (partyIndex == -1) {
        _errorMessage = 'Party not found';

        notifyListeners();

        return false;
      }

      final now = date ?? DateTime.now();

      final transaction = <String, dynamic>{
        'id': now.microsecondsSinceEpoch.toString(),
        'type': type,
        'amount': amount,
        'note': note.trim(),
        'date': now.toIso8601String(),
      };

      final transactions = _parties[partyIndex]['transactions'];

      if (transactions is List) {
        transactions.add(transaction);
      } else {
        _parties[partyIndex]['transactions'] = [transaction];
      }

      await _save();

      notifyListeners();

      return true;
    } catch (e) {
      _errorMessage = 'Failed to add transaction: $e';

      debugPrint('PartyProvider addTransaction error: $e');

      notifyListeners();

      return false;
    }
  }

  // =====================================================
  // UPDATE TRANSACTION
  // =====================================================

  Future<bool> updateTransaction({
    required String partyId,
    required String transactionId,
    required String type,
    required double amount,
    String note = '',
  }) async {
    if (amount <= 0) {
      _errorMessage = 'Amount must be greater than zero';

      notifyListeners();

      return false;
    }

    if (type != 'You Give' && type != 'You Take') {
      _errorMessage = 'Invalid transaction type';

      notifyListeners();

      return false;
    }

    try {
      _errorMessage = null;

      final partyIndex = _parties.indexWhere(
        (party) => party['id']?.toString() == partyId,
      );

      if (partyIndex == -1) {
        _errorMessage = 'Party not found';

        notifyListeners();

        return false;
      }

      final transactions = _parties[partyIndex]['transactions'];

      if (transactions is! List) {
        _errorMessage = 'No transactions found';

        notifyListeners();

        return false;
      }

      final transactionIndex = transactions.indexWhere(
        (item) => item is Map && item['id']?.toString() == transactionId,
      );

      if (transactionIndex == -1) {
        _errorMessage = 'Transaction not found';

        notifyListeners();

        return false;
      }

      final transaction = transactions[transactionIndex];

      if (transaction is! Map) {
        return false;
      }

      transaction['type'] = type;
      transaction['amount'] = amount;
      transaction['note'] = note.trim();

      await _save();

      notifyListeners();

      return true;
    } catch (e) {
      _errorMessage = 'Failed to update transaction: $e';

      debugPrint('PartyProvider updateTransaction error: $e');

      notifyListeners();

      return false;
    }
  }

  // =====================================================
  // DELETE TRANSACTION
  // =====================================================

  Future<bool> deleteTransaction({
    required String partyId,
    required String transactionId,
  }) async {
    try {
      _errorMessage = null;

      final partyIndex = _parties.indexWhere(
        (party) => party['id']?.toString() == partyId,
      );

      if (partyIndex == -1) {
        _errorMessage = 'Party not found';

        notifyListeners();

        return false;
      }

      final transactions = _parties[partyIndex]['transactions'];

      if (transactions is! List) {
        _errorMessage = 'No transactions found';

        notifyListeners();

        return false;
      }

      final transactionIndex = transactions.indexWhere(
        (item) => item is Map && item['id']?.toString() == transactionId,
      );

      if (transactionIndex == -1) {
        _errorMessage = 'Transaction not found';

        notifyListeners();

        return false;
      }

      transactions.removeAt(transactionIndex);

      await _save();

      notifyListeners();

      return true;
    } catch (e) {
      _errorMessage = 'Failed to delete transaction: $e';

      debugPrint('PartyProvider deleteTransaction error: $e');

      notifyListeners();

      return false;
    }
  }

  // =====================================================
  // GET PARTY BY ID
  // =====================================================

  Map<String, dynamic>? getPartyById(String partyId) {
    for (final party in _parties) {
      if (party['id']?.toString() == partyId) {
        return party;
      }
    }

    return null;
  }

  // =====================================================
  // GET PARTY TRANSACTIONS
  // =====================================================

  List<Map<String, dynamic>> getPartyTransactions(String partyId) {
    final party = getPartyById(partyId);

    if (party == null) {
      return [];
    }

    final transactions = party['transactions'];

    if (transactions is! List) {
      return [];
    }

    return transactions
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  // =====================================================
  // CLEAR ERROR
  // =====================================================

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // =====================================================
  // PRIVATE SAVE
  // =====================================================

  Future<void> _save() async {
    final parties = _parties
        .map((party) => PartyModel.fromJson(Map<String, dynamic>.from(party)))
        .toList();

    await _repository.saveAll(parties);
  }

  // =====================================================
  // LOADING
  // =====================================================

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  // =====================================================
  // DOUBLE CONVERTER
  // =====================================================

  double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    if (value != null) {
      return double.tryParse(value.toString()) ?? 0;
    }

    return 0;
  }
}
