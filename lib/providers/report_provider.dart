import 'package:flutter/foundation.dart';

import '../repositories/report_repository.dart';

class ReportProvider extends ChangeNotifier {
  ReportProvider({ReportRepository? repository})
    : _repository = repository ?? ReportRepository();

  final ReportRepository _repository;

  bool _isLoading = false;
  String? _error;

  double _totalRiceAmount = 0;
  double _totalWheatAmount = 0;
  double _totalStockValue = 0;
  double _totalAccountBalance = 0;

  bool get isLoading => _isLoading;
  String? get error => _error;

  double get totalRiceAmount => _totalRiceAmount;
  double get totalWheatAmount => _totalWheatAmount;
  double get totalStockValue => _totalStockValue;
  double get totalAccountBalance => _totalAccountBalance;

  Future<void> loadReports() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _totalRiceAmount = await _repository.getTotalRiceAmount();

      _totalWheatAmount = await _repository.getTotalWheatAmount();

      _totalStockValue = await _repository.getTotalStockValue();

      _totalAccountBalance = await _repository.getTotalAccountBalance();
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
