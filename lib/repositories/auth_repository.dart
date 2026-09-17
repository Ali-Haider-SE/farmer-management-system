import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_model.dart';

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
  static const String _baseUrl = 'http://localhost:5000/api';
  static const String _currentUserKey = 'current_user';
  static const String _tokenKey = 'auth_token';

  Future<UserModel?> authenticate({
    required String username,
    required String password,
    required String role,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username.trim(),
        'password': password,
        'role': role,
      }),
    );

    Map<String, dynamic> data;

    try {
      data = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }

    if (response.statusCode != 200 || data['success'] != true) {
      return null;
    }

    final token = data['token']?.toString();

    if (token == null || token.isEmpty) {
      return null;
    }

    final userData = data['user'];

    if (userData is! Map) {
      return null;
    }

    final user = UserModel.fromJson(Map<String, dynamic>.from(userData));

    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(_tokenKey, token);
    await prefs.setString(_currentUserKey, jsonEncode(user.toJson()));

    return user;
  }

  Future<UserModel?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();

    final token = prefs.getString(_tokenKey);

    if (token == null || token.isEmpty) {
      return null;
    }

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/auth/me'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode != 200) {
        await logout();
        return null;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (data['success'] != true || data['user'] is! Map) {
        await logout();
        return null;
      }

      final user = UserModel.fromJson(Map<String, dynamic>.from(data['user']));

      await prefs.setString(_currentUserKey, jsonEncode(user.toJson()));

      return user;
    } catch (_) {
      return null;
    }
  }

  Future<bool> saveCurrentUser(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.setString(_currentUserKey, jsonEncode(user.toJson()));
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(_currentUserKey);
    await prefs.remove(_tokenKey);
  }

  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<bool> changePassword({
    required String userId,
    required String newPassword,
  }) async {
    return false;
  }
}
