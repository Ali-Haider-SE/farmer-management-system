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

  Future<void> loadDashboard() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _totalParties = (await _partyRepository.getParties()).length;
      _totalAccounts = _accountRepository.getAccounts().length;
      _totalStockItems = _stockRepository.getStock().length;

      _totalRiceAmount = _reportRepository.getTotalRiceAmount();

      _totalWheatAmount = _reportRepository.getTotalWheatAmount();

      _totalStockValue = _reportRepository.getTotalStockValue();

      _totalAccountBalance = _reportRepository.getTotalAccountBalance();
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
