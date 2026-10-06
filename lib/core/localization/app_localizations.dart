import 'package:flutter/widgets.dart';

class AppLocalizations {
  const AppLocalizations(this.locale);

  final Locale locale;

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const supportedLocales = <Locale>[
    Locale('en'),
    Locale('ur'),
  ];

  static AppLocalizations of(BuildContext context) {
    final value = Localizations.of<AppLocalizations>(
      context,
      AppLocalizations,
    );
    return value ?? const AppLocalizations(Locale('en'));
  }

  String get(String key) {
    final dictionary = locale.languageCode == 'ur' ? _ur : _en;
    return dictionary[key] ?? _en[key] ?? key;
  }

  static const Map<String, String> _en = {
    'appName': 'Farmer Management System',
    'login': 'Login',
    'logout': 'Logout',
    'dashboard': 'Dashboard',
    'farms': 'Farm Management',
    'rice': 'Rice Management',
    'wheat': 'Wheat Management',
    'parties': 'Parties / Khata',
    'accounts': 'Accounts',
    'stock': 'Stock Management',
    'reports': 'Reports',
    'settings': 'Settings',
    'save': 'Save',
    'update': 'Update',
    'delete': 'Delete',
    'cancel': 'Cancel',
    'edit': 'Edit',
    'search': 'Search',
    'add': 'Add',
    'close': 'Close',
    'loading': 'Loading...',
    'noData': 'No data available',
    'somethingWentWrong': 'Something went wrong.',
    

    // Settings page
    'settingsSubtitle': 'Manage application preferences and account options.',
    'appearance': 'Appearance',
    'theme': 'Theme',
    'themeSubtitle': 'Choose Light, Dark, or follow the system.',
    'light': 'Light',
    'dark': 'Dark',
    'auto': 'Auto',
    'compactMode': 'Compact Mode',
    'compactModeSubtitle': 'Tighter spacing and smaller controls across every screen.',
    'notifications': 'Notifications',
    'enableNotifications': 'Enable Notifications',
    'enableNotificationsSubtitle': 'Get alerts for low stock, khata dues, and other reminders.',
    'clearNotificationHistory': 'Clear Notification History',
    'clearNotificationHistorySubtitle': 'Remove all read and unread notifications.',
    'notificationsCleared': 'Notifications cleared',
    'business': 'Business',
    'businessName': 'Business Name',
    'language': 'Language',
    'currency': 'Currency',
    'dateFormat': 'Date Format',
    'backupRestore': 'Backup & Restore',
    'createBackup': 'Create Backup',
    'createBackupSubtitle': 'Create a backup of your current application data.',
    'restoreBackup': 'Restore Backup',
    'restoreBackupSubtitle': 'Restore previously backed-up application data.',
    'account': 'Account',
    'currentRole': 'Current Role',
    'signOutSubtitle': 'Sign out from the current account.',
    'application': 'Application',
    'about': 'About',
    'aboutSubtitle': 'View application information and version.',
    'resetSettings': 'Reset Settings',
    'resetSettingsSubtitle': 'Restore application preferences to defaults.',
    'resetSettingsDialogTitle': 'Reset Settings',
    'resetSettingsDialogBody': 'Reset all preferences (theme, compact mode, notifications, language, currency, date format) to their default values?',
    'settingsResetSuccess': 'Settings reset successfully',
    'logoutConfirmTitle': 'Logout',
    'logoutConfirmBody': 'Are you sure you want to logout from the current account?',
    'appVersionFooter': 'Farmer Management System • Version 1.0.0',
    'appAboutBody': 'Farmer Management System\n\nVersion: 1.0.0\n\nManagement for farms, parties, accounts, rice, wheat, stock, reports and business records.',
  };

  static const Map<String, String> _ur = {
    'appName': 'فارمر مینجمنٹ سسٹم',
    'login': 'لاگ اِن',
    'logout': 'لاگ آؤٹ',
    'dashboard': 'ڈیش بورڈ',
    'farms': 'فارم مینجمنٹ',
    'rice': 'چاول مینجمنٹ',
    'wheat': 'گندم مینجمنٹ',
    'parties': 'پارٹیز / کھاتہ',
    'accounts': 'اکاؤنٹس',
    'stock': 'اسٹاک مینجمنٹ',
    'reports': 'رپورٹس',
    'settings': 'سیٹنگز',
    'save': 'محفوظ کریں',
    'update': 'اپ ڈیٹ',
    'delete': 'حذف کریں',
    'cancel': 'منسوخ کریں',
    'edit': 'ترمیم',
    'search': 'تلاش',
    'add': 'شامل کریں',
    'close': 'بند کریں',
    'loading': 'لوڈ ہو رہا ہے...',
    'noData': 'کوئی ڈیٹا دستیاب نہیں',
    'somethingWentWrong': 'کچھ غلط ہو گیا۔',


    // Settings page
    'settingsSubtitle': 'ایپلیکیشن کی ترجیحات اور اکاؤنٹ کے اختیارات منظم کریں۔',
    'appearance': 'ظاہری شکل',
    'theme': 'تھیم',
    'themeSubtitle': 'لائٹ، ڈارک، یا سسٹم کے مطابق منتخب کریں۔',
    'light': 'لائٹ',
    'dark': 'ڈارک',
    'auto': 'خودکار',
    'compactMode': 'کمپیکٹ موڈ',
    'compactModeSubtitle': 'ہر اسکرین پر تنگ فاصلہ اور چھوٹے کنٹرولز۔',
    'notifications': 'نوٹیفیکیشنز',
    'enableNotifications': 'نوٹیفیکیشنز فعال کریں',
    'enableNotificationsSubtitle': 'کم اسٹاک، کھاتہ واجبات اور دیگر یاد دہانیوں کے لیے الرٹس حاصل کریں۔',
    'clearNotificationHistory': 'نوٹیفیکیشن ہسٹری صاف کریں',
    'clearNotificationHistorySubtitle': 'تمام پڑھی اور غیر پڑھی نوٹیفیکیشنز ہٹا دیں۔',
    'notificationsCleared': 'نوٹیفیکیشنز صاف کر دی گئیں',
    'business': 'کاروبار',
    'businessName': 'کاروبار کا نام',
    'language': 'زبان',
    'currency': 'کرنسی',
    'dateFormat': 'تاریخ کا فارمیٹ',
    'backupRestore': 'بیک اپ اور بحالی',
    'createBackup': 'بیک اپ بنائیں',
    'createBackupSubtitle': 'اپنے موجودہ ایپلیکیشن ڈیٹا کا بیک اپ بنائیں۔',
    'restoreBackup': 'بیک اپ بحال کریں',
    'restoreBackupSubtitle': 'پہلے سے محفوظ کردہ ایپلیکیشن ڈیٹا بحال کریں۔',
    'account': 'اکاؤنٹ',
    'currentRole': 'موجودہ کردار',
    'signOutSubtitle': 'موجودہ اکاؤنٹ سے سائن آؤٹ کریں۔',
    'application': 'ایپلیکیشن',
    'about': 'کے بارے میں',
    'aboutSubtitle': 'ایپلیکیشن کی معلومات اور ورژن دیکھیں۔',
    'resetSettings': 'سیٹنگز ری سیٹ کریں',
    'resetSettingsSubtitle': 'ایپلیکیشن کی ترجیحات کو ڈیفالٹ پر بحال کریں۔',
    'resetSettingsDialogTitle': 'سیٹنگز ری سیٹ کریں',
    'resetSettingsDialogBody': 'تمام ترجیحات (تھیم، کمپیکٹ موڈ، نوٹیفیکیشنز، زبان، کرنسی، تاریخ کا فارمیٹ) کو ان کی ڈیفالٹ اقدار پر ری سیٹ کریں؟',
    'settingsResetSuccess': 'سیٹنگز کامیابی سے ری سیٹ ہو گئیں',
    'logoutConfirmTitle': 'لاگ آؤٹ',
    'logoutConfirmBody': 'کیا آپ واقعی موجودہ اکاؤنٹ سے لاگ آؤٹ کرنا چاہتے ہیں؟',
    'appVersionFooter': 'فارمر مینجمنٹ سسٹم • ورژن 1.0.0',
    'appAboutBody': 'فارمر مینجمنٹ سسٹم\n\nورژن: 1.0.0\n\nفارمز، پارٹیز، اکاؤنٹس، چاول، گندم، اسٹاک، رپورٹس اور کاروباری ریکارڈز کا انتظام۔',
  };
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      AppLocalizations.supportedLocales.any(
        (item) => item.languageCode == locale.languageCode,
      );

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      AppLocalizations(locale);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
