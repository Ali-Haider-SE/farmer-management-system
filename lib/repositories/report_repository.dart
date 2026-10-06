import '../models/account_model.dart';
import '../models/party_model.dart';
import '../models/rice_transaction_model.dart';
import '../models/stock_model.dart';
import '../models/wheat_transaction_model.dart';
import '../services/api_service.dart';

class ReportRepository {
  ReportRepository({ApiService? apiService})
    : _api = apiService ?? ApiService.instance;

  final ApiService _api;

  Future<List<RiceTransactionModel>> getRiceTransactions({
    DateTime? start,
    DateTime? end,
  }) async {
    final response = await _api.get('/rice');
    if (response is! List) return [];
    final items = response
        .whereType<Map>()
        .map(
          (item) => RiceTransactionModel.fromJson({
            'id': item['id'],
            'farmerId': item['farmer_id'],
            'partyId': item['party_id'],
            'date': item['date'],
            'quantity': item['quantity'],
            'rate': item['rate'],
            'totalAmount': item['total_amount'],
            'transactionType':
                item['transaction_type']?.toString() == 'sale'
                    ? 'Sale'
                    : 'Purchase',
            'paidAmount': item['paid_amount'],
            'receivedAmount': item['received_amount'],
            'remainingAmount': item['remaining_amount'],
            'variety': item['variety'],
            'notes': item['notes'],
          }),
        )
        .toList();
    return _filterByDate(items, (item) => item.date, start, end);
  }

  Future<List<WheatTransactionModel>> getWheatTransactions({
    DateTime? start,
    DateTime? end,
  }) async {
    final response = await _api.get('/wheat');
    if (response is! List) return [];
    final items = response
        .whereType<Map>()
        .map(
          (item) => WheatTransactionModel.fromJson({
            'id': item['id'],
            'farmerId': item['farmer_id'],
            'partyId': item['party_id'],
            'date': item['date'],
            'quantity': item['quantity'],
            'rate': item['rate'],
            'totalAmount': item['total_amount'],
            'transactionType':
                item['transaction_type']?.toString() == 'sale'
                    ? 'Sale'
                    : 'Purchase',
            'paidAmount': item['paid_amount'],
            'receivedAmount': item['received_amount'],
            'remainingAmount': item['remaining_amount'],
            'variety': item['variety'],
            'notes': item['notes'],
          }),
        )
        .toList();
    return _filterByDate(items, (item) => item.date, start, end);
  }

  Future<List<PartyModel>> getParties() async {
    final response = await _api.get('/parties');
    if (response is! Map || response['parties'] is! List) return [];
    return (response['parties'] as List)
        .whereType<Map>()
        .map((item) => PartyModel.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<List<AccountModel>> getAccounts() async {
    final response = await _api.get('/accounts');
    if (response is! Map || response['accounts'] is! List) return [];
    return (response['accounts'] as List)
        .whereType<Map>()
        .map((item) => AccountModel.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<List<StockModel>> getStock() async {
    final response = await _api.get('/stock');
    if (response is! Map || response['stock'] is! List) return [];
    return (response['stock'] as List)
        .whereType<Map>()
        .map((item) => StockModel.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<double> getTotalRiceAmount({DateTime? start, DateTime? end}) async =>
      (await getRiceTransactions(start: start, end: end))
          .fold<double>(0, (total, item) => total + item.totalAmount);

  Future<double> getTotalWheatAmount({DateTime? start, DateTime? end}) async =>
      (await getWheatTransactions(start: start, end: end))
          .fold<double>(0, (total, item) => total + item.totalAmount);

  Future<double> getTotalStockValue() async =>
      (await getStock()).fold<double>(0, (total, item) => total + item.totalValue);

  Future<double> getTotalAccountBalance() async =>
      (await getAccounts()).fold<double>(0, (total, item) => total + item.currentBalance);

  Future<List<Map<String, dynamic>>> getAccountTransactions({
    DateTime? start,
    DateTime? end,
  }) async {
    final accounts = await getAccounts();
    final all = <Map<String, dynamic>>[];
    for (final account in accounts) {
      final response = await _api.get('/accounts/${account.id}/transactions');
      if (response is Map && response['transactions'] is List) {
        for (final item in (response['transactions'] as List).whereType<Map>()) {
          final map = Map<String, dynamic>.from(item);
          final rawDate = DateTime.tryParse(map['date']?.toString() ?? '');
          if (rawDate == null || _inRange(rawDate, start, end)) {
            all.add(map);
          }
        }
      }
    }
    return all;
  }

  bool _inRange(DateTime date, DateTime? start, DateTime? end) {
    final day = DateTime(date.year, date.month, date.day);
    if (start != null &&
        day.isBefore(DateTime(start.year, start.month, start.day))) {
      return false;
    }
    if (end != null &&
        day.isAfter(DateTime(end.year, end.month, end.day))) {
      return false;
    }
    return true;
  }

  List<T> _filterByDate<T>(
    List<T> items,
    DateTime Function(T item) dateOf,
    DateTime? start,
    DateTime? end,
  ) {
    if (start == null && end == null) return items;
    return items.where((item) => _inRange(dateOf(item), start, end)).toList();
  }
}
