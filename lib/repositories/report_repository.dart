import '../models/account_model.dart';
import '../models/party_model.dart';
import '../models/rice_transaction_model.dart';
import '../models/stock_model.dart';
import '../models/wheat_transaction_model.dart';
import '../services/storage_service.dart';

class ReportRepository {
  ReportRepository({StorageService? storageService})
    : _storage = storageService ?? StorageService.instance;

  final StorageService _storage;

  static const String _riceKey = 'rice_transactions';
  static const String _wheatKey = 'wheat_transactions';
  static const String _partyKey = 'parties_data';
  static const String _accountKey = 'accounts';
  static const String _accountTransactionsKey = 'accounts_transactions';
  static const String _stockKey = 'stock';

  List<Map<String, dynamic>> getAccountTransactionsRaw() {
    final canonical = _storage.getJsonList(_accountTransactionsKey);
    if (canonical.isNotEmpty) return canonical;

    // Backward compatibility for projects created before the canonical
    // accounts_transactions key was introduced.
    return _storage.getJsonList('accounts_data');
  }

  List<Map<String, dynamic>> getTransactions({
    DateTime? start,
    DateTime? end,
  }) {
    final items = getAccountTransactionsRaw();
    if (start == null && end == null) return items;

    final startDay = start == null
        ? null
        : DateTime(start.year, start.month, start.day);
    final endDay = end == null
        ? null
        : DateTime(end.year, end.month, end.day);

    return items.where((item) {
      final raw = item['date'];
      final parsed = raw == null ? null : DateTime.tryParse(raw.toString());
      if (parsed == null) return false;
      final day = DateTime(parsed.year, parsed.month, parsed.day);
      if (startDay != null && day.isBefore(startDay)) return false;
      if (endDay != null && day.isAfter(endDay)) return false;
      return true;
    }).toList();
  }

  double getIncome({DateTime? start, DateTime? end}) => _sumByType(
    getTransactions(start: start, end: end),
    'Income',
  );

  double getExpense({DateTime? start, DateTime? end}) => _sumByType(
    getTransactions(start: start, end: end),
    'Expense',
  );

  double getNetBalance({DateTime? start, DateTime? end}) =>
      getIncome(start: start, end: end) -
      getExpense(start: start, end: end);

  double _sumByType(List<Map<String, dynamic>> items, String type) {
    return items.fold<double>(0, (total, item) {
      if (item['type']?.toString() != type) return total;
      final value = item['amount'];
      final amount = value is num
          ? value.toDouble()
          : double.tryParse(value?.toString() ?? '') ?? 0;
      return total + amount;
    });
  }

  List<RiceTransactionModel> getRiceTransactions() {
    return _storage
        .getJsonList(_riceKey)
        .map(RiceTransactionModel.fromJson)
        .toList();
  }

  List<WheatTransactionModel> getWheatTransactions() {
    return _storage
        .getJsonList(_wheatKey)
        .map(WheatTransactionModel.fromJson)
        .toList();
  }

  List<Map<String, dynamic>> getPartiesRaw() {
    return _storage.getJsonList(_partyKey);
  }

  List<PartyModel> getParties() {
    return _storage.getJsonList(_partyKey).map(PartyModel.fromJson).toList();
  }

  List<AccountModel> getAccounts() {
    return _storage
        .getJsonList(_accountKey)
        .map(AccountModel.fromJson)
        .toList();
  }

  List<StockModel> getStock() {
    return _storage.getJsonList(_stockKey).map(StockModel.fromJson).toList();
  }

  double getTotalRiceAmount() {
    return getRiceTransactions().fold(
      0,
      (total, item) => total + item.totalAmount,
    );
  }

  double getTotalWheatAmount() {
    return getWheatTransactions().fold(
      0,
      (total, item) => total + item.totalAmount,
    );
  }

  double getTotalStockValue() {
    return getStock().fold(0, (total, item) => total + item.totalValue);
  }

  double getTotalAccountBalance() {
    return getAccounts().fold<double>(
      0,
      (total, item) => total + item.currentBalance,
    );
  }
}
