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

  // ============================================================
  // LOAD ACCOUNTS FROM API
  // ============================================================

  Future<void> loadAccounts() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // IMPORTANT:
      // Accounts are now loaded from the backend API/PostgreSQL.
      //
      // Existing SharedPreferences data is NOT deleted,
      // migrated, or overwritten.
      _accounts = await _repository.getAccountsFromApi();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ============================================================
  // ACCOUNT HELPERS
  // ============================================================

  List<AccountModel> get activeAccounts {
    return _accounts.where((account) => account.isActive).toList();
  }

  double get totalBalance {
    return _accounts.fold(
      0,
      (total, account) => total + account.currentBalance,
    );
  }

  AccountModel? getAccountById(String id) {
    for (final account in _accounts) {
      if (account.id == id) {
        return account;
      }
    }

    return null;
  }

  // ============================================================
  // CREATE / UPDATE ACCOUNT THROUGH API
  // ============================================================

  Future<bool> saveAccount(AccountModel account) async {
    _error = null;
    notifyListeners();

    try {
      final existingIndex = _accounts.indexWhere(
        (item) => item.id == account.id,
      );

      late final AccountModel savedAccount;

      if (existingIndex >= 0) {
        // Existing account → UPDATE API
        savedAccount = await _repository.updateAccountApi(account);

        _accounts[existingIndex] = savedAccount;
      } else {
        // New account → CREATE API
        savedAccount = await _repository.createAccountApi(account);

        _accounts = [..._accounts, savedAccount];
      }

      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // ============================================================
  // DELETE ACCOUNT THROUGH API
  // ============================================================

  Future<bool> deleteAccount(String id) async {
    _error = null;
    notifyListeners();

    try {
      await _repository.deleteAccountApi(id);

      _accounts = _accounts.where((account) => account.id != id).toList();

      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // ============================================================
  // ACCOUNT SUMMARY
  // ============================================================

  Future<Map<String, dynamic>?> loadAccountSummary() async {
    try {
      _error = null;

      final summary = await _repository.getAccountSummaryApi();

      return summary;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  // ============================================================
  // ERROR
  // ============================================================

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
