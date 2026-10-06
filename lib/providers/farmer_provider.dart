import 'package:flutter/foundation.dart';

import '../models/farmer_model.dart';
import '../repositories/farmer_repository.dart';

class FarmerProvider extends ChangeNotifier {
  final FarmerRepository _repository = FarmerRepository();

  List<FarmerModel> _farmers = [];
  bool _isLoading = false;
  String? _error;

  List<FarmerModel> get farmers => _farmers;

  bool get isLoading => _isLoading;

  String? get error => _error;

  Future<void> loadFarmers() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _farmers = await _repository.getFarmers();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addFarmer(FarmerModel farmer) async {
    _error = null;

    try {
      final createdFarmer = await _repository.createFarmer(farmer);

      _farmers = [createdFarmer, ..._farmers];

      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateFarmer(FarmerModel farmer) async {
    _error = null;

    try {
      final updatedFarmer = await _repository.updateFarmer(farmer);

      final index = _farmers.indexWhere((item) => item.id == farmer.id);

      if (index != -1) {
        _farmers[index] = updatedFarmer;
      }

      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteFarmer(String id) async {
    _error = null;

    try {
      await _repository.deleteFarmer(id);

      _farmers.removeWhere((farmer) => farmer.id == id);

      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  FarmerModel? getFarmerById(String id) {
    try {
      return _farmers.firstWhere((farmer) => farmer.id == id);
    } catch (_) {
      return null;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
