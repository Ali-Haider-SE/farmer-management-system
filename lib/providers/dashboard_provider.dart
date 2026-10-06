import 'package:flutter/foundation.dart';

import '../repositories/account_repository.dart';
import '../repositories/party_repository.dart';
import '../repositories/report_repository.dart';
import '../repositories/stock_repository.dart';

class DashboardProvider extends ChangeNotifier {
  DashboardProvider({
    ReportRepository? reportRepository,
    PartyRepository? partyRepository,
    AccountRepository? accountRepository,
    StockRepository? stockRepository,
  }) : _reportRepository = reportRepository ?? ReportRepository(),
       _partyRepository = partyRepository ?? PartyRepository(),
       _accountRepository = accountRepository ?? AccountRepository(),
       _stockRepository = stockRepository ?? StockRepository();

  final ReportRepository _reportRepository;
  final PartyRepository _partyRepository;
  final AccountRepository _accountRepository;
  final StockRepository _stockRepository;

  bool _isLoading = false;
  String? _error;

  int _totalParties = 0;
  int _totalAccounts = 0;
  int _totalStockItems = 0;

  double _totalRiceAmount = 0;
  double _totalWheatAmount = 0;
  double _totalStockValue = 0;
  double _totalAccountBalance = 0;

  bool get isLoading => _isLoading;
  String? get error => _error;

  int get totalParties => _totalParties;
  int get totalAccounts => _totalAccounts;
  int get totalStockItems => _totalStockItems;

  double get totalRiceAmount => _totalRiceAmount;
  double get totalWheatAmount => _totalWheatAmount;
  double get totalStockValue => _totalStockValue;
  double get totalAccountBalance => _totalAccountBalance;

  Future<void> loadDashboard({String role = 'Admin'}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final canParties = role.toLowerCase() == 'admin' || role.toLowerCase() == 'accountant';
    final canAccounts = role.toLowerCase() == 'admin' || role.toLowerCase() == 'accountant';
    final canStock = role.toLowerCase() == 'admin' || role.toLowerCase() == 'farm manager' || role.toLowerCase() == 'rice/wheat manager';
    final canRice = role.toLowerCase() == 'admin' || role.toLowerCase() == 'rice/wheat manager';
    final canWheat = role.toLowerCase() == 'admin' || role.toLowerCase() == 'rice/wheat manager';

    try {
      if (canParties) {
        try {
          _totalParties = (await _partyRepository.getParties()).length;
        } catch (_) {}
      }

      if (canAccounts) {
        try {
          _totalAccounts = (await _accountRepository.getAccountsFromApi()).length;
          _totalAccountBalance = await _reportRepository.getTotalAccountBalance();
        } catch (_) {}
      }

      if (canStock) {
        try {
          _totalStockItems = (await _stockRepository.getStockFromApi()).length;
          _totalStockValue = await _reportRepository.getTotalStockValue();
        } catch (_) {}
      }

      if (canRice) {
        try {
          _totalRiceAmount = await _reportRepository.getTotalRiceAmount();
        } catch (_) {}
      }

      if (canWheat) {
        try {
          _totalWheatAmount = await _reportRepository.getTotalWheatAmount();
        } catch (_) {}
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
