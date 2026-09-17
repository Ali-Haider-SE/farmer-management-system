import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences-backed key/value persistence used by the repositories.
///
/// Works on Web, Android, iOS, Windows, Linux and macOS with no
/// platform-specific code (no dart:io, no sqflite).
class StorageService {
  StorageService._();

  static final StorageService instance = StorageService._();

  SharedPreferences? _prefs;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _prefs = await SharedPreferences.getInstance();
    _initialized = true;
  }

  SharedPreferences get _p {
    final prefs = _prefs;
    if (prefs == null) {
      throw StateError(
        'StorageService has not been initialized. '
        'Call StorageService.instance.init() first.',
      );
    }
    return prefs;
  }

  Future<bool> setString(String key, String value) => _p.setString(key, value);

  String? getString(String key) => _p.getString(key);

  Future<bool> setBool(String key, bool value) => _p.setBool(key, value);

  bool? getBool(String key) => _p.getBool(key);

  Future<bool> setInt(String key, int value) => _p.setInt(key, value);

  int? getInt(String key) => _p.getInt(key);

  Future<bool> setDouble(String key, double value) => _p.setDouble(key, value);

  double? getDouble(String key) => _p.getDouble(key);

  Future<bool> setStringList(String key, List<String> value) =>
      _p.setStringList(key, value);

  List<String>? getStringList(String key) => _p.getStringList(key);

  Future<bool> setJson(String key, Map<String, dynamic> value) =>
      setString(key, jsonEncode(value));

  Map<String, dynamic>? getJson(String key) {
    final value = getString(key);
    if (value == null || value.isEmpty) return null;
    try {
      final decoded = jsonDecode(value);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    } catch (_) {
      return null;
    }
  }

  Future<bool> setJsonList(String key, List<Map<String, dynamic>> value) =>
      setString(key, jsonEncode(value));

  List<Map<String, dynamic>> getJsonList(String key) {
    final value = getString(key);
    if (value == null || value.isEmpty) return [];
    try {
      final decoded = jsonDecode(value);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  Future<bool> remove(String key) => _p.remove(key);

  bool containsKey(String key) => _p.containsKey(key);

  Future<bool> clear() => _p.clear();

  Future<void> close() async {
    _prefs = null;
    _initialized = false;
  }
}
