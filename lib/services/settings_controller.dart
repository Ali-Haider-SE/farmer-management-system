import 'package:flutter/material.dart';

import 'storage_service.dart';

/// Application-wide settings.
///
/// This is the single source of truth for user preferences. Unlike the old
/// `settings_page.dart` implementation (which only saved values to
/// SharedPreferences without anything actually reading them back), every
/// value here is applied live across the whole app:
///
///  * [themeMode] drives `MaterialApp.themeMode` (Light / Dark / System).
///  * [compactMode] drives `ThemeData.visualDensity` and a `density` scale
///    that widgets can read via [SettingsController.density] to shrink
///    paddings/row heights.
///  * [notificationsEnabled] gates whether [NotificationCenter] is allowed
///    to raise new system alerts (low stock, khata due, etc).
///
/// It is a singleton `ChangeNotifier` so it can be listened to from
/// `app.dart` without pulling in the `provider` package.
class SettingsController extends ChangeNotifier {
  SettingsController._();

  static final SettingsController instance = SettingsController._();

  static const _kThemeMode = 'settings_theme_mode';
  static const _kCompactMode = 'settings_compact_mode';
  static const _kNotificationsEnabled = 'settings_notifications_enabled';
  static const _kLanguage = 'settings_language';
  static const _kCurrency = 'settings_currency';
  static const _kDateFormat = 'settings_date_format';
  static const _kBusinessName = 'settings_business_name';

  bool _isLoaded = false;
  bool get isLoaded => _isLoaded;

  ThemeMode _themeMode = ThemeMode.light;
  ThemeMode get themeMode => _themeMode;

  bool _compactMode = false;
  bool get compactMode => _compactMode;

  bool _notificationsEnabled = true;
  bool get notificationsEnabled => _notificationsEnabled;

  String _language = 'English';
  String get language => _language;

  String _currency = 'PKR';
  String get currency => _currency;

  String _dateFormat = 'dd MMM yyyy';
  String get dateFormat => _dateFormat;

  String _businessName = 'Farmer Management System';
  String get businessName => _businessName;

  /// Density multiplier other widgets can use for compact spacing, e.g.
  /// `EdgeInsets.all(16 * SettingsController.instance.density)`.
  double get density => _compactMode ? 0.72 : 1.0;

  VisualDensity get visualDensity =>
      _compactMode ? VisualDensity.compact : VisualDensity.standard;

  Future<void> load() async {
    final storage = StorageService.instance;

    final storedTheme = storage.getString(_kThemeMode);
    _themeMode = switch (storedTheme) {
      'dark' => ThemeMode.dark,
      'system' => ThemeMode.system,
      _ => ThemeMode.light,
    };

    _compactMode = storage.getBool(_kCompactMode) ?? false;
    _notificationsEnabled = storage.getBool(_kNotificationsEnabled) ?? true;
    _language = storage.getString(_kLanguage) ?? 'English';
    _currency = storage.getString(_kCurrency) ?? 'PKR';
    _dateFormat = storage.getString(_kDateFormat) ?? 'dd MMM yyyy';
    _businessName =
        storage.getString(_kBusinessName) ?? 'Farmer Management System';

    _isLoaded = true;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    await StorageService.instance.setString(_kThemeMode, switch (mode) {
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
      ThemeMode.light => 'light',
    });
  }

  Future<void> setCompactMode(bool value) async {
    _compactMode = value;
    notifyListeners();
    await StorageService.instance.setBool(_kCompactMode, value);
  }

  Future<void> setNotificationsEnabled(bool value) async {
    _notificationsEnabled = value;
    notifyListeners();
    await StorageService.instance.setBool(_kNotificationsEnabled, value);
  }

  Future<void> setLanguage(String value) async {
    _language = value;
    notifyListeners();
    await StorageService.instance.setString(_kLanguage, value);
  }

  Future<void> setCurrency(String value) async {
    _currency = value;
    notifyListeners();
    await StorageService.instance.setString(_kCurrency, value);
  }

  Future<void> setDateFormat(String value) async {
    _dateFormat = value;
    notifyListeners();
    await StorageService.instance.setString(_kDateFormat, value);
  }

  Future<void> setBusinessName(String value) async {
    _businessName = value;
    notifyListeners();
    await StorageService.instance.setString(_kBusinessName, value);
  }

  Future<void> resetToDefaults() async {
    _themeMode = ThemeMode.light;
    _compactMode = false;
    _notificationsEnabled = true;
    _language = 'English';
    _currency = 'PKR';
    _dateFormat = 'dd MMM yyyy';
    _businessName = 'Farmer Management System';
    notifyListeners();

    final storage = StorageService.instance;
    await Future.wait([
      storage.remove(_kThemeMode),
      storage.remove(_kCompactMode),
      storage.remove(_kNotificationsEnabled),
      storage.remove(_kLanguage),
      storage.remove(_kCurrency),
      storage.remove(_kDateFormat),
      storage.remove(_kBusinessName),
    ]);
  }
}
