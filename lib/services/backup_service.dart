import 'dart:convert';

import 'storage_service.dart';

class BackupService {
  BackupService._();

  static final BackupService instance = BackupService._();

  final StorageService _storage = StorageService.instance;

  Future<String> createBackup(List<String> storageKeys) async {
    final Map<String, dynamic> backupData = {};

    for (final key in storageKeys) {
      final value = _storage.getString(key);

      if (value != null) {
        backupData[key] = value;
      }
    }

    final backup = {
      'version': '1.0.0',
      'createdAt': DateTime.now().toIso8601String(),
      'data': backupData,
    };

    return jsonEncode(backup);
  }

  Future<bool> restoreBackup(String backupJson) async {
    try {
      final decoded = jsonDecode(backupJson);

      if (decoded is! Map<String, dynamic>) {
        return false;
      }

      final data = decoded['data'];

      if (data is! Map<String, dynamic>) {
        return false;
      }

      for (final entry in data.entries) {
        final value = entry.value;

        if (value is String) {
          await _storage.setString(entry.key, value);
        }
      }

      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> clearStoredData(List<String> storageKeys) async {
    try {
      for (final key in storageKeys) {
        await _storage.remove(key);
      }

      return true;
    } catch (_) {
      return false;
    }
  }
}
