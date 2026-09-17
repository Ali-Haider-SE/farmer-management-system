import 'package:flutter/foundation.dart';

import '../models/stock_model.dart';
import '../repositories/stock_repository.dart';

class StockProvider extends ChangeNotifier {
  StockProvider({StockRepository? repository})
    : _repository = repository ?? StockRepository();

  final StockRepository _repository;

  List<StockModel> _stock = [];
  bool _isLoading = false;
  String? _error;

  List<StockModel> get stock => List.unmodifiable(_stock);

  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadStock() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _stock = _repository.getStock();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  List<StockModel> search(String query) {
    final value = query.trim().toLowerCase();

    if (value.isEmpty) {
      return _stock;
    }

    return _stock.where((item) {
      return item.productName.toLowerCase().contains(value) ||
          item.productType.toLowerCase().contains(value);
    }).toList();
  }

  double get totalStockValue {
    return _stock.fold(0, (total, item) => total + item.totalValue);
  }

  Future<bool> saveStock(StockModel item) async {
    try {
      await _repository.save(item);
      _stock = _repository.getStock();
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteStock(String id) async {
    try {
      await _repository.delete(id);
      _stock = _repository.getStock();
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
