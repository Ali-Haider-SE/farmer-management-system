import 'package:flutter/foundation.dart';

import '../models/farm_model.dart';
import '../repositories/farm_repository.dart';

class FarmProvider extends ChangeNotifier {
  FarmProvider({FarmRepository? repository})
    : _repository = repository ?? FarmRepository();

  final FarmRepository _repository;

  List<FarmModel> _farms = [];
  bool _isLoading = false;
  String? _error;

  List<FarmModel> get farms => List.unmodifiable(_farms);
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadFarms() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _farms = await _repository.getFarms();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<List<Map<String, dynamic>>> loadFarmRecords() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      return await _repository.getFarmRecords();
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> saveFarmRecords(List<Map<String, dynamic>> records) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _repository.saveFarmRecords(records);
      await loadFarms();
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  List<FarmModel> getByFarmer(String farmerId) {
    return _farms.where((farm) => farm.farmerId == farmerId).toList();
  }

  Future<bool> saveFarm(FarmModel farm) async {
    try {
      if (farm.id.isEmpty) {
        await _repository.addFarm(farm);
      } else {
        await _repository.updateFarm(farm);
      }

      _farms = await _repository.getFarms();
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteFarm(String id) async {
    try {
      await _repository.deleteFarm(id);
      _farms = await _repository.getFarms();
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
