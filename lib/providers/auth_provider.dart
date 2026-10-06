import 'package:flutter/foundation.dart';

import '../models/user_model.dart';
import '../repositories/auth_repository.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider({AuthRepository? repository})
    : _repository = repository ?? AuthRepository();

  final AuthRepository _repository;

  UserModel? _currentUser;
  bool _isInitializing = false;
  bool _isAuthenticating = false;
  String? _error;
  bool _isServerUnreachable = false;

  UserModel? get currentUser => _currentUser;

  bool get isLoading => _isInitializing || _isAuthenticating;
  bool get isInitializing => _isInitializing;
  bool get isAuthenticating => _isAuthenticating;

  bool get isLoggedIn => _currentUser != null;

  String? get error => _error;
  bool get isServerUnreachable => _isServerUnreachable;

  Future<void> initialize() async {
    _isInitializing = true;
    _isServerUnreachable = false;
    _clearError();
    notifyListeners();

    try {
      _currentUser = await _repository.getCurrentUser();
    } catch (e) {
      _error = e.toString();
      if (e is ApiException && e.isNetworkError) {
        _isServerUnreachable = true;
      }
    } finally {
      _isInitializing = false;
      notifyListeners();
    }
  }

  Future<UserModel?> authenticate({
    required String username,
    required String password,
    required String role,
  }) async {
    _isAuthenticating = true;
    _isServerUnreachable = false;
    _clearError();
    notifyListeners();

    try {
      final user = await _repository.authenticate(
        username: username,
        password: password,
        role: role,
      );

      _currentUser = user;

      return user;
    } catch (e) {
      if (e is ApiException) {
        _error = e.message;
        if (e.isNetworkError) {
          _isServerUnreachable = true;
        }
      } else {
        _error = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
      }
      return null;
    } finally {
      _isAuthenticating = false;
      notifyListeners();
    }
  }

  Future<bool> saveUser(UserModel user) async {
    _isAuthenticating = true;
    _clearError();
    notifyListeners();

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
      _isAuthenticating = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    _isAuthenticating = true;
    _clearError();
    notifyListeners();

    try {
      await _repository.logout();
      _currentUser = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _currentUser = null;
      _isAuthenticating = false;
      notifyListeners();
    }
  }

  void clearError() {
    _clearError();
    notifyListeners();
  }

  void _clearError() {
    _error = null;
  }
}
