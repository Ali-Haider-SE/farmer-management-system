import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/user_model.dart';
import '../services/api_service.dart';

class AuthLockedException implements Exception {
  AuthLockedException(this.remainingSeconds);

  final int remainingSeconds;

  String get friendlyMessage {
    final minutes = (remainingSeconds / 60).ceil();
    return 'Too many failed attempts. Try again in $minutes minute'
        '${minutes == 1 ? '' : 's'}.';
  }

  @override
  String toString() => friendlyMessage;
}

class AuthRepository {
  AuthRepository({ApiService? apiService, FlutterSecureStorage? secureStorage})
    : _api = apiService ?? ApiService.instance,
      _secureStorage = secureStorage ?? const FlutterSecureStorage();

  final ApiService _api;
  final FlutterSecureStorage _secureStorage;

  static const String _currentUserKey = 'current_user';
  static const String _tokenKey = 'auth_token';

  Future<UserModel?> authenticate({
    required String username,
    required String password,
    required String role,
  }) async {
    final response = await _api.post(
      '/auth/login',
      body: {
        'username': username.trim(),
        'password': password,
        'role': role,
      },
    );

    if (response is! Map || response['success'] != true) {
      throw const ApiException(
        message: 'Login failed. Please check your credentials.',
        statusCode: 401,
        type: ApiExceptionType.unauthorized,
      );
    }

    final token = response['token']?.toString();
    final userData = response['user'];

    if (token == null || token.isEmpty || userData is! Map) {
      throw const ApiException(
        message: 'The server returned an invalid login response.',
        type: ApiExceptionType.unknown,
      );
    }

    final user = UserModel.fromJson(Map<String, dynamic>.from(userData));

    await _secureStorage.write(key: _tokenKey, value: token);
    await _secureStorage.write(
      key: _currentUserKey,
      value: jsonEncode(user.toJson()),
    );
    _api.setAccessToken(token);

    return user;
  }

  Future<UserModel?> getCurrentUser() async {
    final token = await getToken();

    if (token == null || token.isEmpty) {
      return null;
    }

    _api.setAccessToken(token);

    try {
      final response = await _api.get('/auth/me');

      if (response is! Map ||
          response['success'] != true ||
          response['user'] is! Map) {
        await logout();
        return null;
      }

      final user = UserModel.fromJson(
        Map<String, dynamic>.from(response['user'] as Map),
      );

      await _secureStorage.write(
        key: _currentUserKey,
        value: jsonEncode(user.toJson()),
      );

      return user;
    } on ApiException catch (error) {
      if (error.isUnauthorized || error.statusCode == 403) {
        await logout();
        return null;
      }
      rethrow;
    }
  }

  Future<bool> saveCurrentUser(UserModel user) async {
    return _secureStorage
        .write(key: _currentUserKey, value: jsonEncode(user.toJson()))
        .then((_) => true);
  }

  Future<void> logout() async {
    await _secureStorage.delete(key: _currentUserKey);
    await _secureStorage.delete(key: _tokenKey);
    _api.clearAuthentication();
  }

  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  Future<String?> getToken() => _secureStorage.read(key: _tokenKey);

  Future<bool> changePassword({
    required String userId,
    required String newPassword,
  }) async {
    final response = await _api.put(
      '/auth/users/$userId/password',
      body: {'newPassword': newPassword},
    );
    return response is Map && response['success'] == true;
  }
}
