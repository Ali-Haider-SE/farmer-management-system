import 'package:flutter/foundation.dart';

import '../models/account_model.dart';
import '../repositories/account_repository.dart';

class AccountProvider extends ChangeNotifier {
  AccountProvider({AccountRepository? repository})
    : _repository = repository ?? AccountRepository();

  final AccountRepository _repository;

  List<AccountModel> _accounts = [];
  bool _isLoading = false;
  String? _error;

  List<AccountModel> get accounts => List.unmodifiable(_accounts);

  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadAccounts() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Load accounts from the backend API/PostgreSQL.
      //
      // IMPORTANT:
      // We are NOT deleting or migrating the existing local
      // SharedPreferences data. It remains untouched for now.
      _accounts = await _repository.getAccountsFromApi();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  List<AccountModel> get activeAccounts {
    return _accounts.where((account) => account.isActive).toList();
  }

  double get totalBalance {
    return _accounts.fold(
      0,
      (total, account) => total + account.currentBalance,
    );
  }

  Future<bool> saveAccount(AccountModel account) async {
    try {
      // Keep local storage behavior unchanged for now.
      // API create/update migration will be handled in a later step.
      await _repository.save(account);
      _accounts = _repository.getAccounts();
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteAccount(String id) async {
    try {
      // Keep local storage behavior unchanged for now.
      // API delete migration will be handled in a later step.
      await _repository.delete(id);
      _accounts = _repository.getAccounts();
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