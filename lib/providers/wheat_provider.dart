import 'package:flutter/foundation.dart';

import '../models/wheat_transaction_model.dart';
import '../repositories/wheat_repository.dart';

class WheatProvider extends ChangeNotifier {
  WheatProvider({WheatRepository? repository})
    : _repository = repository ?? WheatRepository();

  final WheatRepository _repository;

  List<WheatTransactionModel> _transactions = [];
  bool _isLoading = false;
  String? _error;

  List<WheatTransactionModel> get transactions =>
      List.unmodifiable(_transactions);

  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadTransactions() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _transactions = _repository.getTransactions();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  List<WheatTransactionModel> getByFarmer(String farmerId) {
    return _transactions.where((item) => item.farmerId == farmerId).toList();
  }

  List<WheatTransactionModel> getByParty(String partyId) {
    return _transactions.where((item) => item.partyId == partyId).toList();
  }

  Future<bool> saveTransaction(WheatTransactionModel transaction) async {
    try {
      await _repository.save(transaction);
      _transactions = _repository.getTransactions();
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteTransaction(String id) async {
    try {
      await _repository.delete(id);
      _transactions = _repository.getTransactions();
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
