import 'package:flutter/foundation.dart';

import '../models/rice_transaction_model.dart';
import '../repositories/rice_repository.dart';

class RiceProvider extends ChangeNotifier {
  RiceProvider({RiceRepository? repository})
    : _repository = repository ?? RiceRepository();

  final RiceRepository _repository;

  List<RiceTransactionModel> _transactions = [];
  bool _isLoading = false;
  String? _error;

  List<RiceTransactionModel> get transactions =>
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

  List<RiceTransactionModel> getByFarmer(String farmerId) {
    return _transactions.where((item) => item.farmerId == farmerId).toList();
  }

  List<RiceTransactionModel> getByParty(String partyId) {
    return _transactions.where((item) => item.partyId == partyId).toList();
  }

  Future<bool> saveTransaction(RiceTransactionModel transaction) async {
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
