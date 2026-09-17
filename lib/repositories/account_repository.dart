import 'dart:convert';

import '../models/account_model.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';

class AccountRepository {
  AccountRepository({StorageService? storageService, ApiService? apiService})
    : _storage = storageService ?? StorageService.instance,
      _api = apiService ?? ApiService.instance;

  final StorageService _storage;
  final ApiService _api;

  static const String _key = 'accounts';
  static const String transactionsKey = 'accounts_transactions';

  // ============================================================
  // LOCAL STORAGE
  // ============================================================

  /// Legacy map-based account transactions.
  ///
  /// Kept for backward compatibility with existing local data.
  List<Map<String, dynamic>> getRawTransactions() {
    return _storage.getJsonList(transactionsKey);
  }

  Future<void> saveRawTransactions(List<Map<String, dynamic>> items) async {
    await _storage.setJsonList(transactionsKey, items);

    // Keep the legacy key synchronized so older screens/backups
    // remain compatible with the existing local data.
    await _storage.setString('accounts_data', jsonEncode(items));
  }

  List<AccountModel> getAccounts() {
    return _storage.getJsonList(_key).map(AccountModel.fromJson).toList();
  }

  List<AccountModel> getActiveAccounts() {
    return getAccounts().where((account) => account.isActive).toList();
  }

  AccountModel? getById(String id) {
    for (final account in getAccounts()) {
      if (account.id == id) {
        return account;
      }
    }

    return null;
  }

  Future<void> save(AccountModel account) async {
    final accounts = getAccounts();

    final index = accounts.indexWhere((item) => item.id == account.id);

    if (index >= 0) {
      accounts[index] = account;
    } else {
      accounts.add(account);
    }

    await _save(accounts);
  }

  Future<void> delete(String id) async {
    final accounts = getAccounts()
        .where((account) => account.id != id)
        .toList();

    await _save(accounts);
  }

  Future<void> _save(List<AccountModel> accounts) async {
    await _storage.setJsonList(
      _key,
      accounts.map((account) => account.toJson()).toList(),
    );
  }

  Future<void> clear() async {
    await _storage.remove(_key);
  }

  // ============================================================
  // API - ACCOUNTS
  // ============================================================

  /// Get all accounts from the backend.
  ///
  /// Backend response:
  /// {
  ///   success: true,
  ///   count: ...,
  ///   accounts: [...]
  /// }
  Future<List<AccountModel>> getAccountsFromApi() async {
    final response = await _api.get('/accounts');

    if (response is! Map) {
      throw const ApiException(
        message: 'Invalid accounts response from server.',
        type: ApiExceptionType.unknown,
      );
    }

    final accountsData = response['accounts'];

    if (accountsData is! List) {
      throw const ApiException(
        message: 'Invalid accounts data from server.',
        type: ApiExceptionType.unknown,
      );
    }

    return accountsData
        .whereType<Map>()
        .map((item) => AccountModel.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  /// Get one account from the backend.
  ///
  /// The backend also returns that account's transactions.
  Future<AccountModel> getAccountByIdFromApi(String id) async {
    final response = await _api.get('/accounts/$id');

    if (response is! Map) {
      throw const ApiException(
        message: 'Invalid account response from server.',
        type: ApiExceptionType.unknown,
      );
    }

    final accountData = response['account'];

    if (accountData is! Map) {
      throw const ApiException(
        message: 'Account data was not returned by server.',
        type: ApiExceptionType.unknown,
      );
    }

    return AccountModel.fromJson(Map<String, dynamic>.from(accountData));
  }

  /// Create a new account through the backend.
  Future<AccountModel> createAccountApi(AccountModel account) async {
    final response = await _api.post(
      '/accounts',
      body: {
        'name': account.name,
        'accountType': account.accountType,
        'openingBalance': account.openingBalance,
        'description': account.description,
        'isActive': account.isActive,
      },
    );

    if (response is! Map) {
      throw const ApiException(
        message: 'Invalid create account response from server.',
        type: ApiExceptionType.unknown,
      );
    }

    final accountData = response['account'];

    if (accountData is! Map) {
      throw const ApiException(
        message: 'Created account was not returned by server.',
        type: ApiExceptionType.unknown,
      );
    }

    return AccountModel.fromJson(Map<String, dynamic>.from(accountData));
  }

  /// Update an existing account through the backend.
  Future<AccountModel> updateAccountApi(AccountModel account) async {
    final response = await _api.put(
      '/accounts/${account.id}',
      body: {
        'name': account.name,
        'accountType': account.accountType,
        'openingBalance': account.openingBalance,
        'description': account.description,
        'isActive': account.isActive,
      },
    );

    if (response is! Map) {
      throw const ApiException(
        message: 'Invalid update account response from server.',
        type: ApiExceptionType.unknown,
      );
    }

    final accountData = response['account'];

    if (accountData is! Map) {
      throw const ApiException(
        message: 'Updated account was not returned by server.',
        type: ApiExceptionType.unknown,
      );
    }

    return AccountModel.fromJson(Map<String, dynamic>.from(accountData));
  }

  /// Delete an account through the backend.
  Future<void> deleteAccountApi(String id) async {
    await _api.delete('/accounts/$id');
  }

  /// Get account summary from the backend.
  Future<Map<String, dynamic>> getAccountSummaryApi() async {
    final response = await _api.get('/accounts/summary');

    if (response is! Map) {
      throw const ApiException(
        message: 'Invalid account summary response from server.',
        type: ApiExceptionType.unknown,
      );
    }

    final summary = response['summary'];

    if (summary is! Map) {
      throw const ApiException(
        message: 'Account summary was not returned by server.',
        type: ApiExceptionType.unknown,
      );
    }

    return Map<String, dynamic>.from(summary);
  }

  // ============================================================
  // API - ACCOUNT TRANSACTIONS
  // ============================================================

  /// Get all transactions for one account.
  Future<List<Map<String, dynamic>>> getAccountTransactionsFromApi(
    String accountId,
  ) async {
    final response = await _api.get('/accounts/$accountId/transactions');

    if (response is! Map) {
      throw const ApiException(
        message: 'Invalid transactions response from server.',
        type: ApiExceptionType.unknown,
      );
    }

    final transactions = response['transactions'];

    if (transactions is! List) {
      throw const ApiException(
        message: 'Invalid transaction data from server.',
        type: ApiExceptionType.unknown,
      );
    }

    return transactions
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  /// Create an Income or Expense transaction.
  ///
  /// Backend accepts:
  /// - date
  /// - type
  /// - amount
  /// - category
  /// - description
  /// - source
  /// - reference
  ///
  /// The backend generates the transaction ID.
  Future<Map<String, dynamic>> createAccountTransactionApi({
    required String accountId,
    required String type,
    required double amount,
    String? category,
    String? note,
    DateTime? date,
    String? source,
    String? reference,
  }) async {
    final response = await _api.post(
      '/accounts/$accountId/transactions',
      body: {
        'date': date?.toIso8601String(),
        'type': type,
        'amount': amount,
        'category': category,
        'description': note,
        'source': source,
        'reference': reference,
      },
    );

    if (response is! Map) {
      throw const ApiException(
        message: 'Invalid transaction response from server.',
        type: ApiExceptionType.unknown,
      );
    }

    final transaction = response['transaction'];

    if (transaction is! Map) {
      throw const ApiException(
        message: 'Created transaction was not returned by server.',
        type: ApiExceptionType.unknown,
      );
    }

    return {
      'transaction': Map<String, dynamic>.from(transaction),
      'currentBalance': response['currentBalance'],
    };
  }

  /// Delete a transaction from an account.
  ///
  /// Returns the backend-calculated current balance.
  Future<Map<String, dynamic>> deleteAccountTransactionApi({
    required String accountId,
    required String transactionId,
  }) async {
    final response = await _api.delete(
      '/accounts/$accountId/transactions/$transactionId',
    );

    if (response is! Map) {
      throw const ApiException(
        message: 'Invalid delete transaction response from server.',
        type: ApiExceptionType.unknown,
      );
    }

    return {'id': response['id'], 'currentBalance': response['currentBalance']};
  }
}
