import 'package:flutter/foundation.dart';

import '../models/user_model.dart';
import '../repositories/auth_repository.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider({AuthRepository? repository})
    : _repository = repository ?? AuthRepository();

  final AuthRepository _repository;

  UserModel? _currentUser;
  bool _isLoading = false;
  String? _error;

  UserModel? get currentUser => _currentUser;

  bool get isLoading => _isLoading;

  bool get isLoggedIn => _currentUser != null;

  String? get error => _error;

  Future<void> initialize() async {
    _setLoading(true);
    _clearError();

    try {
      _currentUser = await _repository.getCurrentUser();
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  Future<UserModel?> authenticate({
    required String username,
    required String password,
    required String role,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final user = await _repository.authenticate(
        username: username,
        password: password,
        role: role,
      );

      _currentUser = user;

      return user;
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> saveUser(UserModel user) async {
    _setLoading(true);
    _clearError();

    try {
      final success = await _repository.saveCurrentUser(user);

      if (success) {
        _currentUser = user;
      }

      return success;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> logout() async {
    _setLoading(true);
    _clearError();

    try {
      await _repository.logout();
      _currentUser = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  void clearError() {
    _clearError();
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
  }
}
